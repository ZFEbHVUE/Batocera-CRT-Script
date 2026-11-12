# Batocera-CRT-Script v44 - step 12: crt output
# CRT output: menu and 10-monitor.conf, binding to its AMD card (env from the prescan), APU and
# Sea Islands checks -> video_output (DRM name), video_output_xrandr, DISPLAY_ENGINE.
output_detection_and_persist
if [ -z "${CHOSEN:-}" ]; then
  echo "ERROR: No connector selected (CHOSEN is empty). Did you call output_detection_and_persist earlier?"; exit 1
fi
video_output="${KERNEL_CONN_NAME:-$CHOSEN}"; video_output_xrandr="${video_output_xrandr:-$CHOSEN}"
get_card_index_for_connector() {
  local want_raw="$1" base card_part conn_part idx
  normalize_name() {
    local n="$(echo "$1" | tr '[:lower:]' '[:upper:]')"; n="${n/EDP-/EDP-}"; n="${n/LVDS-/LVDS-}"
    n="${n/DISPLAYPORT-/DP-}"; n="$(echo "$n" | sed -E 's/^(HDMI|DVI|DP|VGA|EDP|LVDS)(-[A-Z]+)*/\1-/')"; local t i
    t="$(echo "$n" | sed -E 's/^([A-Z]+).*/\1/')"; i="$(echo "$n" | sed -E 's/.*[^0-9]([0-9]+)$/\1/')"
    [[ "$i" =~ ^[0-9]+$ ]] || i=0; N_TYPE="$t"; N_INDEX="$i"; N_TOKEN="${t}-${i}"
  }
  gen_candidates_for() {
    local t="$1" i="$2" out=()
    case "$t" in
      HDMI) out+=("HDMI-${i}" "HDMI-A-${i}") ;;
      DVI) out+=("DVI-${i}" "DVI-D-${i}" "DVI-I-${i}") ;;
      DP) out+=("DP-${i}") ;;
      VGA) out+=("VGA-${i}") ;;
      EDP) out+=("eDP-${i}" "EDP-${i}") ;;
      LVDS) out+=("LVDS-${i}") ;;
      *) out+=("${t}-${i}") ;;
    esac
    if [[ "$i" -eq 0 || "$i" -eq 1 ]]; then
      local j=$((1 - i))
      case "$t" in
        HDMI) out+=("HDMI-${j}" "HDMI-A-${j}") ;;
        DVI) out+=("DVI-${j}" "DVI-D-${j}" "DVI-I-${j}") ;;
        DP) out+=("DP-${j}") ;;
        VGA) out+=("VGA-${j}") ;;
        EDP) out+=("eDP-${j}" "EDP-${j}") ;;
        LVDS) out+=("LVDS-${j}") ;;
      esac
    fi
    echo "${out[*]}"
  }
  normalize_name "$want_raw"; local WANT_TYPE="$N_TYPE" WANT_INDEX="$N_INDEX" WANT_TOKEN="$N_TOKEN"
  local CANDS=( "$want_raw" "$WANT_TOKEN" $(gen_candidates_for "$WANT_TYPE" "$WANT_INDEX") )
  for base in /sys/class/drm/card*-*; do
    [ -e "$base" ] || continue; card_part="${base%%-*}"; conn_part="${base#*-}"; idx="${card_part#card}"
    [ -r "/tmp/crt-detect/card${idx}.env" ] || continue; normalize_name "$conn_part"; local SYS_TOKEN="$N_TOKEN"
    local sname="$conn_part"; local cand
    for cand in "${CANDS[@]}"; do
      normalize_name "$cand"
      if [[ "$sname" == "$cand" ]] || [[ "$SYS_TOKEN" == "$N_TOKEN" ]]; then
        echo "$idx"; return 0
      fi
    done
  done
  local only=() env
  for env in /tmp/crt-detect/card*.env; do
    [ -r "$env" ] || continue
    only+=("$env")
  done
  if [ "${#only[@]}" -eq 1 ]; then
    echo "$(basename "${only[0]}")" | sed -E 's/^card([0-9]+)\.env/\1/'; return 0
  fi
  if [ -z "$OUT_ENGINE" ]; then engine_from_lspci "${AMD_PCI_ADDR:-${PCI_ADDR:-}}"; fi
return 1
}
use_connector_env() {
  local conn="$1" idx env; idx="$(get_card_index_for_connector "$conn")" || return 1
  env="/tmp/crt-detect/card${idx}.env"; [[ -r "$env" ]] || return 2; . "$env"
  export AMD_IS_APU DISPLAY_ENGINE DISPLAY_VERSION AMD_CARD_INDEX AMD_PCI_ADDR AMD_VENDOR AMD_DEVICE; export APU_REASON
}
if use_connector_env "$video_output"; then
  OUT_ENGINE="${OUT_ENGINE:-$DISPLAY_ENGINE}"; OUT_VERSION="${OUT_VERSION:-$DISPLAY_VERSION}"
  if [ -z "${DISPLAY_ENGINE:-}" ]; then
    if command -v read_engine_anywhere >/dev/null 2>&1; then
      read_engine_anywhere "${AMD_CARD_INDEX:-}"
      DISPLAY_ENGINE="${OUT_ENGINE:-${DISPLAY_ENGINE:-${PARSED_ENGINE:-unknown}}}"
      DISPLAY_VERSION="${OUT_VERSION:-${DISPLAY_VERSION:-${PARSED_VERSION:-}}}"
    else
      {
        for f in /sys/kernel/debug/dri/*/amdgpu_dm_status /sys/kernel/debug/dri/*/amdgpu_pm_info; do [ -r "$f" ] && cat "$f"; done
        dmesg
      } | parse_display_engine_from_text
      DISPLAY_ENGINE="${DISPLAY_ENGINE:-${PARSED_ENGINE:-unknown}}"
      DISPLAY_VERSION="${DISPLAY_VERSION:-${PARSED_VERSION:-}}"
    fi
    OUT_ENGINE="$DISPLAY_ENGINE"; OUT_VERSION="$DISPLAY_VERSION"
  fi
	PCI_ADDR="${PCI_ADDR:-${AMD_PCI_ADDR:-}}"; CARD_INDEX="${CARD_INDEX:-${AMD_CARD_INDEX:-}}"
else
  echo "WARN: Non-AMD GPU or no AMD env for '$video_output'; continuing in generic mode." >> "$LOG_FILE"; AMD_IS_APU=0
  DISPLAY_ENGINE="${DISPLAY_ENGINE:-GENERIC}"; DISPLAY_VERSION="${DISPLAY_VERSION:-}"; AMD_CARD_INDEX=""
  AMD_PCI_ADDR=""; AMD_VENDOR=""; AMD_DEVICE=""; OUT_ENGINE="${OUT_ENGINE:-$DISPLAY_ENGINE}"
  OUT_VERSION="${OUT_VERSION:-$DISPLAY_VERSION}"; PCI_ADDR="${PCI_ADDR:-}"; CARD_INDEX="${CARD_INDEX:-}"
fi
if [ "${AMD_IS_APU:-0}" -eq 1 ]; then
  box_hash; box_center "YOUR VIDEO CARD IS ${GREEN}AN AMD APU${NOCOLOR}"; box_empty
  box_center "APU = CPU with built-in Radeon graphics (integrated)."
  box_center "No separate graphics card is required."; box_hash; box_empty
else
  box_hash; box_center "YOUR VIDEO CARD IS NOT ${GREEN}AN AMD APU${NOCOLOR}"; box_empty
  box_center "This system is using a discrete GPU (a separate graphics card)."
  box_center "Desktop dGPU or mobile dGPU behaves the same for this script."; box_hash; box_empty
fi
center_plain_log "CRT bind: ${video_output} -> card${AMD_CARD_INDEX} (${AMD_PCI_ADDR}) | ${DISPLAY_ENGINE}${DISPLAY_VERSION:+ ${DISPLAY_VERSION}} | AMD_IS_APU=${AMD_IS_APU}"
if [ -n "${AMD_CARD_INDEX:-}" ] && [ -e "/sys/class/drm/card${AMD_CARD_INDEX}/device/driver" ]; then
  _drv="$(basename "$(readlink -f "/sys/class/drm/card${AMD_CARD_INDEX}/device/driver")")"
  echo "Kernel driver for card${AMD_CARD_INDEX}: ${_drv}" >> "$CRT_LOG"
fi
hbox "Display Engine: ${GREEN}${DISPLAY_ENGINE:-NONE}${NOCOLOR}${DISPLAY_VERSION:+ v${DISPLAY_VERSION}}"
echo "Display engine summary: ${DISPLAY_ENGINE:-NONE} ${DISPLAY_VERSION}" >> "$CRT_LOG"
if [ -n "${AMD_CARD_INDEX:-}" ]; then
  if is_sea_islands_chip; then
    _drv="$(get_bound_driver)"
    echo "Sea Islands detection: driver=${_drv}, engine=${DISPLAY_ENGINE:-NONE}, apu=${AMD_IS_APU}" >> "$CRT_LOG"
    if [ "$_drv" = "amdgpu" ]; then
      offer_switch_to_radeon
    else echo "Sea Islands under radeon: OK for interlace." >> "$CRT_LOG"; fi
  fi
else echo "Sea Islands check skipped (helper functions missing or no AMD card bound)" >> "$CRT_LOG"; fi
b71; echo "##                         CRT Output Selected                       ##"; b71; echo
echo -e "   You have chosen output name:  ${GREEN}${video_output}${NOCOLOR}"
echo "  -> Owner: card${AMD_CARD_INDEX} (${AMD_PCI_ADDR}) | ${DISPLAY_ENGINE}${DISPLAY_VERSION:+ ${DISPLAY_VERSION}} | AMD_IS_APU=${AMD_IS_APU}" | tee -a "$CRT_LOG"
echo "   This connector will remain enabled; all others will be ignored via Xorg."; echo; b71; echo
echo -n -e "   PRESS ${BLUE}ENTER${NOCOLOR} TO CONTINUE "; read -r
echo "CRT output selected: ${video_output}" | tee -a "$CRT_LOG"
