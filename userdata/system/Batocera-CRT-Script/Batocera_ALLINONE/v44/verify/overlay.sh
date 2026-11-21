#!/usr/bin/env bash
# Checks the overlay image after the save. The payload read is optional and never writes the image.
# Overlay image freshness evidence. This does not write the image.
# This is an in-process verifier, NOT an overlay writer or a persistence guarantee.
# Source only in the post-confirmation finish path; functions have no side effects until invoked.
OVERLAY_BASELINE_READY=0
OVERLAY_BASELINE_KIND=unknown
OVERLAY_BASELINE_SHA=none
OVERLAY_FRESHNESS=not_checked

overlay_route() {
  if [[ "${IS_PHASE2:-false}" == true ]]; then printf 'phase2'; else printf 'singleboot'; fi
}
overlay_target() {
  local path
  if [[ "${IS_PHASE2:-false}" == true ]]; then path=/boot/crt/overlay;
  else path=/boot/boot/overlay; fi
  # verify_path rejects an unapproved fixture root.
  verify_path "$path"
}
overlay_event() {
  local level="$1" operation="$2" outcome="$3"
  if declare -F log_event >/dev/null 2>&1; then
    log_event "$level" 24_finish "$operation" route "$(overlay_route)" outcome "$outcome" || :
  fi
}
overlay_hash() {
  local path="$1" line digest
  command -v sha256sum >/dev/null 2>&1 || return 2
  line="$(sha256sum -- "$path")" || return 1
  digest="${line%% *}"
  [[ "$digest" =~ ^[[:xdigit:]]{64}$ ]] || return 1
  printf '%s' "$digest"
}
overlay_before() {
  local target
  OVERLAY_BASELINE_READY=0
  OVERLAY_BASELINE_KIND=unknown
  OVERLAY_BASELINE_SHA=none
  OVERLAY_FRESHNESS=not_checked
  target="$(overlay_target)" || { overlay_event ERROR overlay_baseline failed; return 1; }
  if [[ ! -e "$target" && ! -L "$target" ]]; then
    OVERLAY_BASELINE_KIND=absent
  elif [[ ! -f "$target" || -L "$target" || ! -s "$target" ]]; then
    overlay_event ERROR overlay_baseline failed
    return 1
  else
    OVERLAY_BASELINE_SHA="$(overlay_hash "$target")" || {
      overlay_event ERROR overlay_baseline failed
      return 1
    }
    OVERLAY_BASELINE_KIND=present
  fi
  OVERLAY_BASELINE_READY=1
  overlay_event INFO overlay_baseline recorded
  return 0
}
overlay_after() {
  local target digest
  OVERLAY_FRESHNESS=failed
  if [[ "$OVERLAY_BASELINE_READY" != 1 ]]; then
    verify_check 'overlay freshness' FAIL 'baseline not captured before save'
    overlay_event ERROR overlay_freshness failed
    return 1
  fi
  target="$(overlay_target)" || {
    verify_check 'overlay freshness' FAIL 'target path unavailable'
    overlay_event ERROR overlay_freshness failed
    return 1
  }
  if [[ ! -f "$target" || -L "$target" || ! -s "$target" ]]; then
    verify_check 'overlay freshness' FAIL 'image missing, empty, unsafe, or not regular'
    overlay_event ERROR overlay_freshness failed
    return 1
  fi
  digest="$(overlay_hash "$target")" || {
    verify_check 'overlay freshness' FAIL 'image fingerprint unavailable'
    overlay_event ERROR overlay_freshness failed
    return 1
  }
  if [[ "$OVERLAY_BASELINE_KIND" == absent ]]; then
    OVERLAY_FRESHNESS=created
    verify_check 'overlay freshness' PASS 'new image created; payload and reboot unverified'
    overlay_event INFO overlay_freshness created
  elif [[ "$OVERLAY_BASELINE_KIND" == present && "$digest" != "$OVERLAY_BASELINE_SHA" ]]; then
    OVERLAY_FRESHNESS=changed
    verify_check 'overlay freshness' PASS 'image bytes changed; payload and reboot unverified'
    overlay_event INFO overlay_freshness changed
  elif [[ "$OVERLAY_BASELINE_KIND" == present && "$digest" == "$OVERLAY_BASELINE_SHA" ]]; then
    OVERLAY_FRESHNESS=unchanged
    verify_check 'overlay freshness' FAIL 'unchanged after saver; persistence unproven (may be legitimate no-op)'
    overlay_event WARN overlay_freshness unproven
    return 1
  else
    verify_check 'overlay freshness' FAIL 'invalid baseline state'
    overlay_event ERROR overlay_freshness failed
    return 1
  fi
  return 0
}

# Advisory read-only inspection of selected files inside the overlay image.
# Never writes to the image; never sources external code; does not mount anything.
# If inspection cannot be performed, label it UNVERIFIED. A proven byte mismatch is a blocking FAIL.
# Image layout and debugfs availability require real Batocera v44 validation.
PAYLOAD_STATUS=not_checked
PAYLOAD_CHECKS=0
PAYLOAD_MATCHES=0
PAYLOAD_MISSING=0
PAYLOAD_MISMATCHES=0

payload_event() {
  local level="$1" status="$2"
  if declare -F log_event >/dev/null 2>&1; then
    log_event "$level" 24_finish overlay_payload_inspection outcome "$status" checked "$PAYLOAD_CHECKS" matched "$PAYLOAD_MATCHES" missing "$PAYLOAD_MISSING" mismatch "$PAYLOAD_MISMATCHES" || :
  fi
}
payload_note() {
  local msg="$1"
  # Keep informational findings in the install report.
  VERIFY_LINES+=("UNVERIFIED | Overlay image payload | $msg")
}
payload_ext_magic() {
  # ext2/3/4 magic is at superblock + 0x38 = byte 1080.
  local got
  command -v dd >/dev/null 2>&1 && command -v od >/dev/null 2>&1 || return 1
  got="$(dd if="$1" bs=1 skip=1080 count=2 2>/dev/null | od -An -tx1 2>/dev/null)" || return 1
  [[ "$got" =~ ^[[:space:]]*53[[:space:]]+ef[[:space:]]*$ ]]
}
payload_safe_virtual() {
  [[ "$1" == /* && "$1" =~ ^/[a-zA-Z0-9_./-]+$ && "$1" != *..* && "$1" != *//* ]]
}
payload_compare_path() {
  local image="$1" live="$2" virtual="$3" dir="$4" p seen=0 matches=0 errors=0
  payload_safe_virtual "$virtual" || return 2
  if [[ ! -f "$live" || -L "$live" || ! -s "$live" ]]; then
    PAYLOAD_MISSING=$((PAYLOAD_MISSING+1))
    return 2
  fi
  PAYLOAD_CHECKS=$((PAYLOAD_CHECKS+1))
  for p in "$virtual" "/upper${virtual}"; do
    # debugfs may exit 0 for a missing inode: require nonempty bytes and do
    # not count a textual error response as a readable payload.
    if debugfs -R "cat $p" "$image" > "$dir/extracted" 2> "$dir/diagnostic" \
       && [[ -s "$dir/extracted" ]] \
       && ! grep -Eiq 'File not found|not found|invalid inode|permission denied|not a regular file|error reading' "$dir/diagnostic"; then
      seen=$((seen+1))
      if cmp -s -- "$live" "$dir/extracted"; then
        matches=$((matches+1))
      else
        errors=$((errors+1))
      fi
    fi
  done
  if (( seen > 1 && matches > 0 && errors > 0 )); then
    # Both layouts exist but disagree, so there is no trusted unique source.
    PAYLOAD_MISSING=$((PAYLOAD_MISSING+1))
    return 2
  fi
  if (( matches > 0 )); then
    PAYLOAD_MATCHES=$((PAYLOAD_MATCHES+1))
    return 0
  fi
  if (( errors > 0 )); then
    PAYLOAD_MISMATCHES=$((PAYLOAD_MISMATCHES+1))
    return 1
  fi
  PAYLOAD_MISSING=$((PAYLOAD_MISSING+1))
  return 2
}
payload_probe() {
  local image dir file status rc required=(
    /etc/switchres.ini
    /etc/X11/xorg.conf.d/20-modesetting.conf
    /usr/bin/batocera-resolution
    /usr/bin/emulationstation-standalone
    /usr/bin/get_monitorRange
  )
  PAYLOAD_STATUS=unverified
  PAYLOAD_CHECKS=0 PAYLOAD_MATCHES=0 PAYLOAD_MISSING=0 PAYLOAD_MISMATCHES=0
  if ! declare -F overlay_target >/dev/null 2>&1 || ! declare -F verify_path >/dev/null 2>&1; then
    payload_note 'required verifier helpers missing'; payload_event WARN unverified; return 0
  fi
  image="$(overlay_target)" || { payload_note 'overlay path unavailable'; payload_event WARN unverified; return 0; }
  if [[ ! -f "$image" || -L "$image" || ! -s "$image" || ! -r "$image" ]]; then
    payload_note 'image missing or unsafe'; payload_event WARN unverified; return 0
  fi
  if ! command -v debugfs >/dev/null 2>&1; then
    payload_note 'debugfs unavailable on this system'; payload_event WARN unverified; return 0
  fi
  if ! payload_ext_magic "$image"; then
    payload_note 'ext filesystem format not confirmed'; payload_event WARN unverified; return 0
  fi
  dir="$(mktemp -d "${TMPDIR:-/tmp}/overlay-readonly.XXXXXXXX")" || {
    payload_note 'temporary readback area unavailable'; payload_event WARN unverified; return 0
  }
  # Restrict paths to selected root-fs files: /userdata and /boot are excluded
  # because their persistence is independent of the root filesystem overlay.
  if [[ "${Name_monitor_EDID:-}" =~ ^[a-zA-Z0-9_.-]+$ && "${Name_monitor_EDID:-}" != *..* ]]; then
    required+=("/lib/firmware/edid/${Name_monitor_EDID}")
  fi
  for file in "${required[@]}"; do
    local live
    live="$(verify_path "$file")" || { PAYLOAD_MISSING=$((PAYLOAD_MISSING+1)); continue; }
    payload_compare_path "$image" "$live" "$file" "$dir"
    rc=$?
    # Do not depend on inspection being available, but never ignore a confirmed
    # readable-archive mismatch if a developer manually enabled this verifier.
    [[ "$rc" == 0 || "$rc" == 1 || "$rc" == 2 ]] || PAYLOAD_MISSING=$((PAYLOAD_MISSING+1))
  done
  rm -f -- "$dir/extracted" "$dir/diagnostic"
  rmdir -- "$dir" 2>/dev/null || :
  if (( PAYLOAD_MISMATCHES > 0 )); then
    PAYLOAD_STATUS=mismatch
    verify_check 'Overlay payload integrity' FAIL "readable image content differs from live rootfs ($PAYLOAD_MISMATCHES mismatches)"
    payload_event ERROR mismatch
  elif (( PAYLOAD_MISSING > 0 || PAYLOAD_CHECKS == 0 )); then
    PAYLOAD_STATUS=unverified
    payload_note "partial inspection: matched $PAYLOAD_MATCHES of $PAYLOAD_CHECKS; missing $PAYLOAD_MISSING"
    payload_event WARN unverified
  else
    PAYLOAD_STATUS=verified
    verify_check 'Overlay payload integrity' PASS "$PAYLOAD_MATCHES selected rootfs files match image bytes; reboot unverified"
    payload_event INFO verified
  fi
  return 0
}
