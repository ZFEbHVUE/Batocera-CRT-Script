# Batocera-CRT-Script v44 - step 02: amd helpers
# AMD helpers: display engine guessed from the lspci name (engine_from_lspci) and the Sea Islands
# check (GCN 2.x under amdgpu: offer the radeon driver, edit batocera-boot.conf, reboot).
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
offer_switch_to_radeon() {
  local conf="/boot/batocera-boot.conf"; local bak="/boot/batocera-boot.conf.bak_sea_islands"
  echo "Sea Islands: offering driver switch; editing $conf with backup $bak" >> "$CRT_LOG"; box_hash
  box_center "Sea Islands (GCN 2.x / DCE 8.x) detected under ${GREEN}amdgpu${NOCOLOR}."
  box_center "Interlace is ${RED}unsupported${NOCOLOR} on amdgpu for this family."; box_empty
  box_center "Recommended: switch to ${GREEN}radeon${NOCOLOR} driver in /boot/batocera-boot.conf"
  box_center "(this sets: amdgpu=false)"; box_hash
  prompt_centered_tty "PRESS ${BLUE}ENTER${NOCOLOR} TO APPLY (or Ctrl+C to keep amdgpu)"
  mount -o remount,rw /boot 2>/dev/null || true; cp -f "$conf" "$bak" 2>/dev/null || true
  if grep -q '^ *amdgpu=' "$conf" 2>/dev/null; then
    sed -i 's/^ *amdgpu=.*/amdgpu=false/' "$conf"
  else printf '\n# Force radeon for Sea Islands (GCN 2.x)\namdgpu=false\n' >> "$conf"; fi
  sync; box_hash; box_center "batocera-boot.conf updated (${GREEN}amdgpu=false${NOCOLOR})."
  box_center "Reboot to load the radeon driver and enable interlace."; box_hash
  echo "Sea Islands: wrote amdgpu=false to $conf (backup at $bak)" >> "$CRT_LOG"; box_empty
  box_center "Reboot required to load ${GREEN}radeon${NOCOLOR}."
  box_center "System will reboot in 15 seconds…  (press Ctrl+C to cancel)"; box_hash; sync
  mount -o remount,ro /boot 2>/dev/null || true
  for s in $(seq 15 -1 1); do
    printf "\rRebooting in %2d s…  " "$s"; sleep 1
  done
  echo; echo "Sea Islands: initiating reboot now." >> "$CRT_LOG"; reboot
}
