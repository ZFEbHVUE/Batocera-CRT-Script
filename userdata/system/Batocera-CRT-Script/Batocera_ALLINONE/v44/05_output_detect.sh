
# ─────────────────────────────────────────────────────────────────────────────
# New output detection & persistence (terminal-only) as a function Start
# Call this AFTER GPU preflight (e.g., after the R9 380/380X block).
# ─────────────────────────────────────────────────────────────────────────────

# Deterministic XR ↔ DRM resolver with logging
#
# Behavior:
# 1) Deterministic path: read CONNECTOR_ID for the given XRandR output via `xrandr --prop`,
#    then find the matching /sys/class/drm/card*-*/connector_id with the same value.
#    This gives a true 1:1 mapping on amdgpu, i915, and nouveau.
# 2) Fallback: if CONNECTOR_ID is missing or not found in sysfs, use the original heuristic
#    (alias match first, then family+index with DVI-I > DVI-D > DVI-A).
#
# Card preference:
# - If a preferred card is provided (arg $2 or $AMD_CARD_INDEX), search is constrained to that card.
#
# Notes:
# - Does not use "connected" status as a tie-breaker, so disconnected outputs still resolve.
# - NVIDIA proprietary is not supported by the deterministic path; the fallback may still work
#   but is not guaranteed to be correct on that driver.
#
# Args:
#   $1 = XRandR output name (e.g., DP-1, HDMI-2, DVI-I-1)
#   $2 = optional preferred card index (e.g., 0). If empty, all cards are scanned.
#
# Returns:
#   DRM connector token without the "cardX-" prefix (e.g., DP-1, HDMI-A-1, DVI-I-1).
map_xrandr_to_drm() {
  local xr="$1"
  local pref_card="${2:-${AMD_CARD_INDEX:-}}"
  [ -z "$xr" ] && return 1

  # Logging helpers
  local _LOG="${LOG_FILE:-/userdata/system/logs/BUILD_15KHz_Batocera.log}"
  local MAP_LOG_VERBOSE="${MAP_LOG_VERBOSE:-0}"
  _log() { echo "map_xrandr_to_drm: $*" >> "$_LOG"; }

  _log "------------------------------------------------------------"
  _log "XR input='${xr}'  pref_card='${pref_card:-*}'"

  # ------------------------------------------------------------
  # 1) Deterministic path: CONNECTOR_ID join (amdgpu/i915/nouveau)
  #     xrandr --prop -> CONNECTOR_ID -> /sys/class/drm/.../connector_id 
  # ------------------------------------------------------------

  local cid=""
  if command -v xrandr >/dev/null 2>&1; then
	cid="$(DISPLAY=${DISPLAY:-:0} xrandr --prop 2>/dev/null | awk -v o="$xr" '
	$1==o {f=1}
	f && /CONNECTOR_ID:/ {print $2; exit}
	# end section if we hit another connector header
	f && /^[A-Za-z0-9-]+[[:space:]]+(connected|disconnected)/ && $1!=o {exit}
	')"

    if [[ "$cid" =~ ^[0-9]+$ ]]; then
      local search_glob match=""
      if [ -n "$pref_card" ]; then
        search_glob="/sys/class/drm/card${pref_card}-*/connector_id"
      else
        search_glob="/sys/class/drm/card*-*/connector_id"
      fi

      shopt -s nullglob
      for f in $search_glob; do
        if [ -r "$f" ] && [ "$(cat "$f" 2>/dev/null)" = "$cid" ]; then
          match="${f%/connector_id}"
          break
        fi
      done
      shopt -u nullglob

      if [ -n "$match" ]; then
        local base card_idx drm_out
        base="$(basename -- "$match")"
        if [[ "$base" =~ ^card([0-9]+)-(.+)$ ]]; then
          card_idx="${BASH_REMATCH[1]}"
          drm_out="${BASH_REMATCH[2]}"
          _log "CID match: XR='${xr}' CID=${cid} -> ${base} (card=${card_idx})"
          printf '%s\n' "$drm_out"
          return 0
        fi
      else
        _log "CID not found in sysfs for XR='${xr}' CID=${cid}; falling back to heuristic."
      fi
    else
      _log "No CONNECTOR_ID for XR='${xr}'; falling back to heuristic."
    fi
  else
    _log "xrandr not available; falling back to heuristic."
  fi

  # ------------------------------------------------------------
  # 2) Fallback: original heuristic from this script
  #     - Exact alias match (e.g., HDMI-1 == HDMI-A-1, DVI-I-1 stays DVI-I-1)
  #     - Else family+index with DVI-I > DVI-D > DVI-A
  #     - Honors preferred card if provided
  # ------------------------------------------------------------

  # --- Parse XR (keep subtype + full index chain, supports MST like 1-1) ---
  local xr_type_full xr_index_chain
  case "$xr" in
    DVI-I-*|DVI-D-*|DVI-A-*)
      xr_type_full="${xr%%-[0-9]*}"
      xr_index_chain="${xr#${xr_type_full}-}"
      ;;
    *)
      xr_type_full="${xr%%-*}"
      xr_index_chain="${xr#${xr_type_full}-}"
      ;;
  esac

  # Canonicalize some user-facing tokens to families we recognize
  # DisplayPort -> DP, USB-C -> DP, HDMI -> HDMI/HDMI-A (handled later)
  case "$xr_type_full" in
    DisplayPort) xr_type_full="DP" ;;
    USB-C|USBC|Type-C|USB) xr_type_full="DP" ;;
    HDMI-A|HDMI) : ;;
    DVI-I|DVI-D|DVI-A|DVI) : ;;
    eDP|LVDS|VGA) : ;;
    *) : ;;
  esac

  # Snapshot all DRM connectors; prefer pref_card if set
  local best_exact="" best_exact_card=""
  local best_family="" best_family_card="" best_family_rank=99

  # sysfs walk: /sys/class/drm/cardX-<connector>
  shopt -s nullglob
  for p in /sys/class/drm/card*-*; do
    b="$(basename "$p")" || continue
    [[ "$b" =~ ^card([0-9]+)-(.+)$ ]] || continue
    card_idx="${BASH_REMATCH[1]}"
    drm_name="${BASH_REMATCH[2]}"

    # --- Parse DRM name robustly (preserve subtypes like DVI-I / HDMI-A) ---
    # If connector is DVI-*-N or HDMI-A-N, keep the subtype token
    if [[ "$drm_name" == DVI-*-* || "$drm_name" == HDMI-A-* ]]; then
      drm_type="${drm_name%%-[0-9]*}"          # DVI-I or DVI-D or DVI-A, or HDMI-A
      drm_idx_chain="${drm_name#${drm_type}-}" # e.g., "1" or "1-1"
    else
      drm_type="${drm_name%%-*}"               # DP / eDP / LVDS / VGA / HDMI (no -A) / etc.
      drm_idx_chain="${drm_name#${drm_type}-}" # e.g., "1" or "1-1"
    fi

    # Generate XR-style aliases we consider "exact" for this sysfs entry
    # e.g. card0-HDMI-A-1 => exact alias: HDMI-A-1 and HDMI-1
    exact1="${drm_name}"
    case "$drm_type" in
      DP)                alias2="DisplayPort-${drm_idx_chain}" ;;
      HDMI|HDMI-A)       alias2="HDMI-${drm_idx_chain}" ;;
      DVI-I|DVI-D|DVI-A) alias2="DVI-${drm_idx_chain}" ;;
      *)                 alias2="" ;;
    esac

    # Card preference gate (if set, ignore other cards)
    if [ -n "$pref_card" ] && [ "$card_idx" != "$pref_card" ]; then
      continue
    fi

    # 2.1) exact alias match on either exact1 or alias2
    if [ "$xr" = "$exact1" ] || [ -n "$alias2" ] && [ "$xr" = "$alias2" ]; then
      best_exact="$drm_name"
      best_exact_card="$card_idx"
      _log "EXACT alias: XR='${xr}' -> '${drm_name}' (card${card_idx})"
      # don't break; we still want to ensure we prefer the preferred card if multiple
      if [ -n "$pref_card" ]; then
        # already constrained by card, so we can finish
        printf '%s\n' "$best_exact"
        return 0
      fi
      continue
    fi

    # 2.2) Family+index (ranked)
    # Map XR family to DRM family token and choose rank for DVI variants
    family_rank=99
    case "$xr_type_full" in
      DP)
        if [ "$drm_type" = "DP" ] && [ "$drm_idx_chain" = "$xr_index_chain" ]; then
          family_rank=0
        fi
        ;;
      HDMI|HDMI-A)
        if { [ "$drm_type" = "HDMI-A" ] || [ "$drm_type" = "HDMI" ]; } \
           && [ "$drm_idx_chain" = "$xr_index_chain" ]; then
          family_rank=0
        fi
        ;;
      DVI|DVI-I|DVI-D|DVI-A)
        if [[ "$drm_type" =~ ^DVI-(I|D|A)$ ]] && [ "$drm_idx_chain" = "$xr_index_chain" ]; then
          case "$drm_type" in
            DVI-I) family_rank=0 ;;
            DVI-D) family_rank=1 ;;
            DVI-A) family_rank=2 ;;
          esac
        fi
        ;;
      eDP|LVDS|VGA)
        if [ "$drm_type" = "$xr_type_full" ] && [ "$drm_idx_chain" = "$xr_index_chain" ]; then
          family_rank=0
        fi
        ;;
    esac

    if [ "$family_rank" -lt "$best_family_rank" ]; then
      best_family="$drm_name"
      best_family_card="$card_idx"
      best_family_rank="$family_rank"
      _log "FAMILY candidate: XR='${xr}' -> '${drm_name}' (card${card_idx} rank=${family_rank})"
    fi
  done
  shopt -u nullglob

  # Prefer exact (on any card) over family match
  if [ -n "$best_exact" ]; then
    _log "RESOLVE exact (card${best_exact_card}): '${best_exact}'"
    printf '%s\n' "$best_exact"; return 0
  fi
  if [ -n "$best_family" ]; then
    _log "RESOLVE family (card${best_family_card} rank=${best_family_rank}): '${best_family}'"
    printf '%s\n' "$best_family"; return 0
  fi

  # Last resort: conservative guess (keeps subtype if XR provided one)
  local guess=""
  case "$xr_type_full" in
    DisplayPort) guess="DP-${xr_index_chain}" ;;
    HDMI-A)      guess="HDMI-A-${xr_index_chain}" ;;
    HDMI)        guess="HDMI-A-${xr_index_chain}" ;;
    DVI-I|DVI-D|DVI-A) guess="${xr_type_full}-${xr_index_chain}" ;;
    DVI)         guess="DVI-I-${xr_index_chain}" ;;
    eDP|LVDS|VGA) guess="${xr_type_full}-${xr_index_chain}" ;;
    USB-C|USBC|Type-C|USB) guess="DP-${xr_index_chain}" ;;
    *)           guess="${xr_type_full}-${xr_index_chain}" ;;
  esac
  _log "RESOLVE guess: '${guess}'"
  printf '%s\n' "$guess"
  return 0
}

# Snapshot of DRM connectors → XR-style aliases (logged for debugging)
log_drm_map_snapshot() {
  echo "---- DRM connector snapshot (pref card: ${AMD_CARD_INDEX:-*}) ----" >> "$LOG_FILE"
  for p in /sys/class/drm/card*-*; do
    b="$(basename "$p")"
    name="${b#card*-}"
    t="${name%%-*}"
    idx="${name#${t}-}"
    case "$t" in
      DP)                xr1="DisplayPort-${idx}"; xr2="DP-${idx}" ;;
      HDMI|HDMI-A)       xr1="HDMI-${idx}";       xr2="HDMI-A-${idx}" ;;
      DVI-I|DVI-D|DVI-A) xr1="${t}-${idx}";       xr2="DVI-${idx}" ;;
      *)                 xr1="${t}-${idx}";       xr2="" ;;
    esac
    # Prefer the bound AMD card if known; otherwise log all
    if [ -n "${AMD_CARD_INDEX-}" ] && [[ "$b" != card${AMD_CARD_INDEX}-* ]]; then
      continue
    fi
    echo "card${b#card}-  DRM:${name}  XR-candidates: ${xr1}${xr2:+, ${xr2}}" >> "$LOG_FILE"
  done
  echo "--------------------------------" >> "$LOG_FILE"
}

# Resolve the X authority cookie so xrandr works from SSH / non-ES contexts.
# Batocera starts X with `-auth /<path>/.serverauth.<pid>`; without pointing
# XAUTHORITY at that file, xrandr fails with "Authorization required".
ensure_x_authority() {
  export DISPLAY="${DISPLAY:-:0}"

  # Already able to talk to X? nothing to do.
  if xrandr --query >/dev/null 2>&1; then
    return 0
  fi

  # a) exact -auth path from the running X server command line
  local xauth=""
  xauth="$(ps -eo args 2>/dev/null | grep -m1 -oE '/[^ ]*\.serverauth\.[0-9]+' || true)"

  # b) fallback: newest .serverauth.* in common locations
  if [ -z "$xauth" ] || [ ! -f "$xauth" ]; then
    xauth="$(ls -t /.serverauth.* /root/.serverauth.* /var/run/.serverauth.* 2>/dev/null | head -1)"
  fi

  # c) fallback: standard Xauthority files
  if [ -z "$xauth" ] || [ ! -f "$xauth" ]; then
    for cand in /root/.Xauthority "$HOME/.Xauthority" /tmp/.Xauthority; do
      [ -f "$cand" ] && { xauth="$cand"; break; }
    done
  fi

  if [ -n "$xauth" ] && [ -f "$xauth" ]; then
    export XAUTHORITY="$xauth"
    echo "ensure_x_authority: using XAUTHORITY=$xauth" >> "${LOG_FILE:-/tmp/crt_script.log}" 2>/dev/null
  fi

  # last resort: allow local connections to a local root X server
  if ! xrandr --query >/dev/null 2>&1; then
    xhost +local: >/dev/null 2>&1 || true
  fi

  xrandr --query >/dev/null 2>&1
}

output_detection_and_persist() {
  # XRandR-only output detection and persistence into 10-monitor.conf

  export LC_ALL=C
  export LANG=C
  export DISPLAY="${DISPLAY:-:0}"
  ensure_x_authority

  CONF_DIR="/etc/X11/xorg.conf.d"
  CONF_FILE="$CONF_DIR/10-monitor.conf"
  FLAG_FILE="$CHECK_FILE"

  die() { echo "ERROR: $*" >&2; exit 1; }
  timestamp() { date +"%Y.%m.%d,%H.%M.%S"; }
  sanitize_conn() { sed 's/\r//g' | sed 's/[^A-Za-z0-9._:+-]//g'; }
  create_flag_file() { echo "$(timestamp)" > "$FLAG_FILE"; }

  box_title "Output detection (XRandR only)"
  echo "XRandR-only path engaged" >> "$LOG_FILE"

  # 1) Query xrandr once; if X not ready, retry a few times
  ALL_OUTS=()
  CONN_OUTS=()
  for attempt in 1 2 3 4 5; do
	if DISPLAY=${DISPLAY:-:0} xrandr --query >/dev/null 2>&1; then
	mapfile -t XR < <(DISPLAY=${DISPLAY:-:0} xrandr --query 2>/dev/null \
		| awk '/^[^ ]+[[:space:]]+(connected|disconnected)/ {print $1, $2}' \
		| grep -Eiv '^(Writeback|Virtual|VIRTUAL)')

      ALL_OUTS=()
      CONN_OUTS=()
      for ln in "${XR[@]}"; do
        n="${ln%% *}"; st="${ln##* }"
        [ -n "$n" ] || continue
        case "$st" in
          connected) CONN_OUTS+=("$n");;
        esac
        ALL_OUTS+=("$n")
      done
      [ ${#ALL_OUTS[@]} -gt 0 ] && break
    fi
    sleep 1
  done

  if [ ${#ALL_OUTS[@]} -eq 0 ]; then
    box_left "No outputs found via xrandr. Is X running?"
    die "Cannot proceed without xrandr outputs."
  fi

  # 1) If an old config exists: backup → remove → save overlay → reboot NOW
  if [ -f "$CONF_FILE" ]; then
    box_hash
    box_center "Existing Xorg monitor configuration detected:"
    box_center "$CONF_FILE"
    box_empty
    box_center "This file must be removed and the system must reboot before setup runs again."

    backup="${CONF_FILE}.$(timestamp)"
    mv -- "$CONF_FILE" "$backup"
    chmod 000 "$backup" || true

    box_center "Backed up to: $backup"
    batocera-save-overlay >>"$LOG_FILE" 2>&1 || true

    box_empty
    box_center "System will reboot to finish cleanup."
    prompt_centered_tty "PRESS ${GREEN}ENTER${NOCOLOR} TO CONTINUE"
    box_hash

    reboot
    exit 0
  fi

  # 2) If nothing connected, we still allow choosing any port (for DACs/switchers)
  if [ ${#CONN_OUTS[@]} -eq 0 ]; then
    box_left "0 connected outputs reported by xrandr. You can still pick a port to keep active."
  fi
    log_drm_map_snapshot
  # 3) Print choices and prompt
  box_empty
  box_left "Detected outputs (xrandr):"
  idx=1
  for o in "${ALL_OUTS[@]}"; do
    st="disconnected"
    if printf '%s\n' "${CONN_OUTS[@]}" | grep -qx "$o"; then st="connected"; fi
    box_left "  [$idx] $o  ($st)"
    idx=$((idx+1))
  done
  box_empty

  # --- Quick, one-shot rescan via xrandr (no retries, no sleeps) ---
  quick_rescan_outputs() {
	mapfile -t XR < <(DISPLAY=${DISPLAY:-:0} xrandr --query 2>/dev/null \
	  | awk '/^[^ ]+[[:space:]]+(connected|disconnected)/ {print $1, $2}' \
	  | grep -Eiv '^(Writeback|Virtual|VIRTUAL)')

    ALL_OUTS=()
    CONN_OUTS=()
    for ln in "${XR[@]}"; do
      n="${ln%% *}"; st="${ln##* }"
      [ -n "$n" ] || continue
      [ "$st" = "connected" ] && CONN_OUTS+=("$n")
      ALL_OUTS+=("$n")
    done
    echo "Quick rescan: found ${#ALL_OUTS[@]} outputs; connected=${#CONN_OUTS[@]}" >> "$LOG_FILE"
  }

  while :; do
    # A small centered "input box"
    box_hash
    box_empty
    box_center "Enter the number of the output you like to use for CRT output"
    box_center "(press R to rescan outputs once via xrandr)"
    box_empty
    box_hash

    # Center the input cursor using spaces. BOXW is your inner width (used by box_* helpers).
    # We want the caret to start near the center (adjust -2 if you want it a tad left/right).
    pad=$(( (BOXW / 2) - 2 ))
    [ "$pad" -lt 0 ] && pad=0

    # Read the selection with a centered-looking prompt line (not framed).
    # The spaces align the caret; feels like an input field under the box.
    read -rp "$(printf '%*s> ' "$pad")" sel

    # Allow quick one-shot rescan with R/r
    if [[ "$sel" =~ ^[Rr]$ ]]; then
      box_hash
      box_center "Rescanning outputs (single xrandr --query)…"
      box_hash
      quick_rescan_outputs
        log_drm_map_snapshot
      # Reprint the (possibly updated) list
      box_empty
      box_center "Detected outputs (xrandr)"
      idx=1
      for o in "${ALL_OUTS[@]}"; do
        st="disconnected"
        if printf '%s\n' "${CONN_OUTS[@]}" | grep -qx "$o"; then st="connected"; fi
        box_center "  [$idx] $o  ($st)"
        idx=$((idx+1))
      done
      box_empty
      continue
    fi

    # Validate numeric selection
    if ! [[ "$sel" =~ ^[0-9]+$ ]]; then
      box_center "Please enter a number (or press R to rescan)."
      continue
    fi
    if ! { [ "$sel" -ge 1 ] && [ "$sel" -le ${#ALL_OUTS[@]} ]; }; then
      box_center "Out of range. Valid: 1..${#ALL_OUTS[@]} (or press R to rescan)."
      continue
    fi
    CHOSEN="${ALL_OUTS[$((sel-1))]}"
  # Keep xrandr name for Xorg; also compute DRM connector name for syslinux
  video_output_xrandr="$CHOSEN"
  # Prefer the bound AMD card if we have it; harmless if empty on Intel/NVIDIA
  KERNEL_CONN_NAME="$(map_xrandr_to_drm "$CHOSEN" "${AMD_CARD_INDEX:-}")"
  echo "XR->DRM mapping: '$CHOSEN' -> '${KERNEL_CONN_NAME}'" >> "$LOG_FILE"

  # Safety check: verify the resolved DRM connector actually exists in sysfs
  if ! compgen -G "/sys/class/drm/card${AMD_CARD_INDEX:-*}-${KERNEL_CONN_NAME}" >/dev/null; then
    echo "WARN: Could not verify DRM connector card${AMD_CARD_INDEX:-*}-${KERNEL_CONN_NAME} in sysfs." >> "$LOG_FILE"
    box_center "Warning: couldn't verify ${KERNEL_CONN_NAME} under /sys/class/drm. Using it anyway."
  fi

  # On-screen banner: show both names
  box_empty
  box_center "Selected output (XR): ${BLUE}${video_output_xrandr}${NOCOLOR}"
  box_center "Kernel connector (DRM/syslinux): ${GREEN}${KERNEL_CONN_NAME}${NOCOLOR}"
  box_empty

  break
done

  # 4) Recheck chosen status (xrandr-only) after a short settle (optional)
  sleep 1
  if DISPLAY=:0 xrandr --query >/dev/null 2>&1; then
    chosen_status="$(DISPLAY=:0 xrandr --query | awk -v c="$CHOSEN" '$1==c {print $2; exit}')"
    if [ "$chosen_status" != "connected" ]; then
      box_left "${CHOSEN} is currently reported as DISCONNECTED by xrandr. Proceeding anyway."
    else
      box_left "${CHOSEN} is CONNECTED."
    fi
  fi

  # 5) Build 'others' list
  OTHERS=()
  for o in "${ALL_OUTS[@]}"; do
    [ "$o" != "$CHOSEN" ] && OTHERS+=("$o")
  done

  # 6) Persist to 10-monitor.conf (always ignore others)
  mkdir -p "$CONF_DIR"
  {
    echo "# Generated by Batocera-CRT-Script (XRandR-only)"
    echo "# Disables all outputs except the selected one"
    echo
    for o in "${OTHERS[@]}"; do
      o="$(printf '%s' "$o" | sanitize_conn)"
      echo 'Section "Monitor"'
      echo "    Identifier \"$o\""
      echo '    Option "Ignore" "true"'
      echo 'EndSection'
      echo
    done
    echo 'Section "Monitor"'
    echo "    Identifier \"$(printf '%s' "$CHOSEN" | sanitize_conn)\""
    echo 'EndSection'
    echo
  } > "$CONF_FILE"

  chmod 644 "$CONF_FILE"

  # User notice so it doesn't look "stuck" while persisting overlay
  if declare -f box_hash >/dev/null 2>&1; then
    box_hash
    box_center "Saving 10-monitor.conf to persistent storage — please wait (can take ~10–30s)"
    box_hash
  else
    echo "Saving 10-monitor.conf to persistent storage — please wait (can take ~10–30s)"
  fi

  # Time the save for diagnostics
  t0="$(date +%s)"
  batocera-save-overlay >>"$LOG_FILE" 2>&1 || {
    echo "WARN: batocera-save-overlay failed; changes may not persist after reboot." >>"$LOG_FILE"
  }
  t1="$(date +%s)"
  echo "batocera-save-overlay duration: $((t1 - t0))s" >>"$LOG_FILE"

  create_flag_file || true

  echo
  echo "Saved $CONF_FILE"
  echo "  Keep   : $CHOSEN"
  echo "  Ignored: ${OTHERS[*]}"
  echo
}

# ─────────────────────────────────────────────────────────────────────────────
# New output detection & persistence (terminal-only) as a function End!
# ─────────────────────────────────────────────────────────────────────────────
