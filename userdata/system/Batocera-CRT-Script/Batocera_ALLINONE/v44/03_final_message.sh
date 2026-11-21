# Batocera-CRT-Script v44 - step 03: final message
# Final first-boot instructions and reboot prompt (show_first_boot_instructions_and_reboot).
show_first_boot_instructions_and_reboot() {
  : "${BOLD:="\e[1m"}" "${GREEN:="\e[32m"}" "${YELLOW:="\e[33m"}" "${NOCOLOR:="\e[0m"}"
  if [[ -n "${SSH_CONNECTION:-}" ]]; then
    box_hash; box_center "${BOLD}Notice:${NOCOLOR} You are running over SSH."
    box_center "The system will reboot after you press ENTER."; box_hash
  fi
  local output label line
  output="${video_output_xrandr:-${video_output:-}}"
  line=$(grep "Boot_" /userdata/system/videomodes.conf 2>/dev/null \
    | grep "^${H_RES_EDID:-}x${V_RES_EDID:-}\\." | head -1)
  label="${line#*:}"
  [ -n "$output" ] || output="unset"
  if [ -z "$line" ] || [ "$label" = "$line" ]; then label="unset"; fi
  hbox "${BOLD}First Boot After Installation${NOCOLOR}"; box_center ""
  box_center "These values are already set. Verify them if you would like:"
  box_center ""; box_center "MAIN MENU -> SYSTEM SETTINGS"; box_center ""
  box_center "Verify video output is ${BOLD}${output}${NOCOLOR}."
  box_center "Video mode is ${BOLD}${label}${NOCOLOR}."
  box_center ""; box_hash; box_center ""; box_center "${GREEN}${BOLD}Press ENTER to reboot now...${NOCOLOR}"
  box_center ""; box_hash; echo; read -r; reboot
}
