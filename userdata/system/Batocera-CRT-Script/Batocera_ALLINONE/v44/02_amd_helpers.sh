# Batocera-CRT-Script v44 - step 02: amd helpers
# AMD helpers: display engine guessed from the lspci name (engine_from_lspci) and the Sea Islands
# check (GCN 2.x under amdgpu: offer the radeon driver, patch the kernel boot line, reboot).
engine_from_lspci() {
  local NAME_LINE=""
  if command -v lspci >/dev/null 2>&1; then
    if [ -n "$1" ]; then
      NAME_LINE="$(lspci -s "${1#0000:}" -nn 2>/dev/null || true)"
    else NAME_LINE="$(lspci -nn 2>/dev/null | grep -iE 'VGA.*AMD|Display.*AMD' | head -n1 || true)"; fi
  fi
  NAME_LINE="$(printf '%s' "$NAME_LINE" | tr '[:upper:]' '[:lower:]')"
  if printf '%s' "$NAME_LINE" | grep -qE '(navi|rdna|sienna|phoenix|rembrandt|vangogh|aero|merce|navi [0-9]+)'; then
    OUT_ENGINE="DCN"; OUT_VERSION=""; echo "Engine detect: heuristic => DCN (from lspci name: $NAME_LINE)" >> "$CRT_LOG"
  elif printf '%s' "$NAME_LINE" | grep -qE '(polaris|tonga|hawaii|bonaire|pitcairn|kabini|kaveri|carrizo|stoney|cape verde|curacao|oland|tahiti|verde|gfx7|gfx8)'; then
    OUT_ENGINE="DCE"; OUT_VERSION=""; echo "Engine detect: heuristic => DCE (from lspci name: $NAME_LINE)" >> "$CRT_LOG"
  fi
}
is_sea_islands_chip() {
  local hint="${CHIP_FAMILY:-}"
  if [ -z "$hint" ]; then
    local l=""
    if command -v lspci >/dev/null 2>&1; then l="$(lspci -s "${AMD_PCI_ADDR#0000:}" -nn 2>/dev/null | tr '[:upper:]' '[:lower:]')"; fi
    hint="$l"
  fi
  printf '%s' "$hint" | grep -qiE '(chip_)?(bonaire|hawaii|kaveri|kabini|mullins)' && return 0
  printf '%s' "$hint" | grep -qiE '(kalindi|spectre|spooky)' && return 0; return 1
}
get_bound_driver() {
  local dev="/sys/class/drm/card${AMD_CARD_INDEX}/device"
  local drv=""; drv="$(basename "$(readlink -f "$dev/driver" 2>/dev/null)" 2>/dev/null || true)"; printf '%s' "$drv"
}
# v44 does not read amdgpu=false. Sea Islands (CIK) binds radeon only when the
# kernel command line disables amdgpu for CIK and enables radeon for CIK.
SEA_ISLANDS_RADEON_PARAMS="amdgpu.cik_support=0 radeon.cik_support=1"
SEA_ISLANDS_RADEON_MARKER="/userdata/system/Batocera-CRT-Script/.sea_islands_radeon"
# A LABEL crt entry is the CRT boot on a dual-boot system, so the Wayland entry
# is left alone. Stock syslinux has no LABEL crt, and every APPEND line is updated.
sea_islands_patch_syslinux() {
  local f="$1" tmp="${f}.patched"
  if grep -q '^LABEL crt$' "$f"; then
    awk -v params="$SEA_ISLANDS_RADEON_PARAMS" '
      /^LABEL crt$/ { in_crt=1 }
      /^LABEL / && !/^LABEL crt$/ { in_crt=0 }
      in_crt && /^[[:space:]]*APPEND / && $0 !~ /radeon\.cik_support=1/ { print $0 " " params; next }
      { print }
    ' "$f" > "$tmp" || return 1
  else
    awk -v params="$SEA_ISLANDS_RADEON_PARAMS" '
      /^[[:space:]]*APPEND / && $0 !~ /radeon\.cik_support=1/ { print $0 " " params; next }
      { print }
    ' "$f" > "$tmp" || return 1
  fi
  mv -f "$tmp" "$f"
  chmod 755 "$f" 2>/dev/null || true
}
offer_switch_to_radeon() {
  local f patched=0
  local SYS_CAND="/boot/EFI/syslinux.cfg /boot/EFI/BOOT/syslinux.cfg /boot/EFI/batocera/syslinux.cfg /boot/boot/syslinux.cfg /boot/boot/syslinux/syslinux.cfg"
  echo "Sea Islands: offering radeon switch via kernel command line" >> "$CRT_LOG"
  box_hash
  box_center "Sea Islands (GCN 2.x / DCE 8.x) detected under ${GREEN}amdgpu${NOCOLOR}."
  box_center "Interlace is ${RED}unsupported${NOCOLOR} on amdgpu for this family."; box_empty
  box_center "Recommended: load the ${GREEN}radeon${NOCOLOR} driver for this card."
  box_center "The kernel boot line will include:"
  box_center "${SEA_ISLANDS_RADEON_PARAMS}"; box_hash
  prompt_centered_tty "PRESS ${BLUE}ENTER${NOCOLOR} TO APPLY (or Ctrl+C to keep amdgpu)"
  mount -o remount,rw /boot 2>/dev/null || true
  for f in $SYS_CAND; do
    [ -f "$f" ] || continue
    cp -f "$f" "${f}.bak" 2>/dev/null || true
    if [ ! -f "${f}.initial" ]; then cp -f "$f" "${f}.initial" 2>/dev/null || true; fi
    if ! sea_islands_patch_syslinux "$f"; then
      echo "Sea Islands: failed to update $f" | tee -a "$CRT_LOG"
      continue
    fi
    patched=1
    echo "Sea Islands: added ${SEA_ISLANDS_RADEON_PARAMS} to $f" | tee -a "$CRT_LOG"
  done
  if [ "$patched" -eq 0 ]; then
    box_hash
    box_center "${RED}No syslinux.cfg found. The radeon driver was not enabled.${NOCOLOR}"; box_hash
    echo "Sea Islands: no syslinux.cfg to update" >> "$CRT_LOG"
    exit 1
  fi
  mkdir -p "$(dirname "$SEA_ISLANDS_RADEON_MARKER")"
  printf '%s\n' "$SEA_ISLANDS_RADEON_PARAMS" > "$SEA_ISLANDS_RADEON_MARKER"
  echo "Sea Islands: marker written to $SEA_ISLANDS_RADEON_MARKER" >> "$CRT_LOG"
  sync; box_hash; box_center "Kernel boot line updated."
  box_center "Reboot to load the radeon driver and enable interlace."; box_hash; box_empty
  box_center "Reboot required to load ${GREEN}radeon${NOCOLOR}."
  box_center "System will reboot in 15 seconds…  (press Ctrl+C to cancel)"; box_hash; sync
  mount -o remount,ro /boot 2>/dev/null || true
  for s in $(seq 15 -1 1); do
    printf "\rRebooting in %2d s…  " "$s"; sleep 1
  done
  echo; echo "Sea Islands: initiating reboot now." >> "$CRT_LOG"; reboot
}
