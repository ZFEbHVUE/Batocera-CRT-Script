# Batocera-CRT-Script v44 - step 23: install review
REVIEW_CHOICE=""
read_review_choice() {
  local choice=""
  while :; do
    box_empty
    box_center "1  Confirm and save"
    box_center "2  ${1}"
    box_center "3  Cancel"
    box_empty
    if [ -e /dev/tty ]; then
      IFS= read -r choice </dev/tty || choice=""
    else IFS= read -r choice || choice=""; fi
    case "$choice" in
      1|2|3) REVIEW_CHOICE="$choice"; return 0 ;;
      *) box_center "Enter 1, 2, or 3." ;;
    esac
  done
}
es_override_value() {
  local key="$1" line value
  line=$(grep -E "^${key}[[:space:]]" /userdata/system/es.arg.override 2>/dev/null | head -1)
  value=${line#"$key"}
  value=${value#"${value%%[![:space:]]*}"}
  printf '%s' "$value"
}
es_menu_position_changed() {
  local key value
  [ -s /userdata/system/es.arg.override ] || return 1
  for key in screenoffset_x screenoffset_y screensizeoffset_x screensizeoffset_y; do
    value=$(es_override_value "$key")
    case "$value" in
      ''|*[!0-9-]*) continue ;;
    esac
    [ "$value" -eq 0 ] 2>/dev/null && continue
    return 0
  done
  return 1
}
ask_keep_es_position() {
  CRT_KEEP_ES_POSITION=0
  CRT_PRIOR_ES_ARGS=""
  es_menu_position_changed || return 0
  CRT_PRIOR_ES_ARGS=$(mktemp) || { CRT_PRIOR_ES_ARGS=""; return 0; }
  cp -a /userdata/system/es.arg.override "$CRT_PRIOR_ES_ARGS" || { CRT_PRIOR_ES_ARGS=""; return 0; }
  local choice=""
  box_empty
  box_center "The EmulationStation menu has a saved position."
  box_center "Horizontal position: $(es_override_value screenoffset_x)"
  box_center "Vertical position: $(es_override_value screenoffset_y)"
  box_center "Horizontal size: $(es_override_value screensizeoffset_x)"
  box_center "Vertical size: $(es_override_value screensizeoffset_y)"
  while :; do
    box_empty
    box_center "1  Keep this menu position"
    box_center "2  Reset the menu position"
    box_empty
    if [ -e /dev/tty ]; then
      IFS= read -r choice </dev/tty || choice=""
    else IFS= read -r choice || choice=""; fi
    case "$choice" in
      1) CRT_KEEP_ES_POSITION=1; box_center "Menu position: Keep"; return 0 ;;
      2) CRT_KEEP_ES_POSITION=0; box_center "Menu position: Reset"; return 0 ;;
      *) box_center "Enter 1 or 2." ;;
    esac
  done
}
review_crt_plan() {
  hbox "Review the CRT install"
  box_empty
  box_center "Card: ${selected_card:-unknown}  (${TYPE_OF_CARD:-unknown})"
  if [ -n "${Drivers_Nvidia_CHOICE:-}" ] && [ "${Drivers_Nvidia_CHOICE}" != "NONE" ]; then
    box_center "Driver: ${Drivers_Nvidia_CHOICE} ${Drivers_Name_Nvidia_CHOICE:-}"
  fi
  local usb_poll="Default"
  if [ "${polling_rate:-}" = "usbhid.jspoll=1 xpad.cpoll=1" ]; then
    usb_poll="On"
  fi
  box_center "Output: ${video_output:-unset}"
  if [ "${CRT_KEEP_GEOMETRY:-0}" = 1 ]; then
    box_center "Monitor Profile: custom"
    box_center "Geometry: Keep your adjustments"
    if [ -n "${CRT_GEOMETRY_RANGES:-}" ]; then
      while IFS= read -r _range; do
        [ -n "$_range" ] && printf '%s\n' "$_range" | _log_tee
      done <<EOF
${CRT_GEOMETRY_RANGES}
EOF
    fi
  else
    box_center "Monitor Profile: ${monitor_firmware:-unset}"
  fi
  box_center "Dotclock: ${dotclock_min:-unset}"
  box_center "Super-res: ${super_width:-unset}"
  box_center "Boot Resolution: ${EDID_resolution:-unset}"
  box_center "Rotation: ${Rotating_screen:-unset}"
  box_center "ES Orientation: ${ES_rotation:-unset}"
  box_center "Advanced: ${DT_SR_Choice:-NO}"
  box_center "USB Fast Polling: ${usb_poll}"
  local encoders="None"
  if declare -p CRT_ENCODER_NAMES >/dev/null 2>&1 && [ "${#CRT_ENCODER_NAMES[@]}" -gt 0 ]; then
    encoders="${CRT_ENCODER_NAMES[*]}"
  fi
  box_center "USB Encoders: ${encoders}"
  box_center "GunCon2 Calibration: ${Guncon2_x:-320}x${Guncon2_y:-240}@${Guncon2_freq:-60}"
  ask_keep_es_position
  box_empty
  if [ "${IS_PHASE2:-false}" = true ]; then
    box_center "Confirming writes the boot entry, system files, and CRT overlay."
    box_center "The machine then shuts down. Power it on to boot CRT mode."
  else
    box_center "Confirming writes the boot entry, system files, and overlay."
    box_center "The machine then reboots into CRT mode."
  fi
  box_center "Cancel leaves the boot partition unchanged."
  box_hash
  read_review_choice "Change answers"
}
discard_unconfirmed_install_files() {
  # Only discard private generated data. Never delete or restore live user EDIDs.
  stage_discard
}
install_selected_videomodes() {
  local src=""
  if [ "${Amd_NvidiaND_IntelDP:-0}" = "1" ]; then
    src="${CRTD}/System_configs/VideoModes/Amd_NvidiaND_IntelDP/${Name_VideoModes:-}"
  elif [ "${Intel_Nvidia_NOUV:-0}" = "1" ]; then
    src="${CRTD}/System_configs/VideoModes/Intel_NvidiaNOUV/${Name_VideoModes:-}"
  else
    err_box "No videomodes set for this card."
    return 1
  fi
  if [ ! -f "$src" ]; then
    err_box "Missing videomodes file: ${src}"
    return 1
  fi
  # All three writes are mandatory once the user has confirmed the plan.
  # Do not let a later successful command hide a failed copy or chmod.
  cp "$src" /userdata/system/videomodes.conf || return $?
  chmod 644 /userdata/system/videomodes.conf || return $?
  cp /userdata/system/videomodes.conf /userdata/system/videomodes.conf.bak || return $?
}
