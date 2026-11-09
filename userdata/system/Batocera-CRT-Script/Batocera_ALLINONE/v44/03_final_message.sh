# Batocera-CRT-Script v44 - step 03: final message
# Final first-boot instructions and reboot prompt (show_first_boot_instructions_and_reboot).
show_first_boot_instructions_and_reboot() {
  : "${BOLD:="\e[1m"}" "${GREEN:="\e[32m"}" "${YELLOW:="\e[33m"}" "${NOCOLOR:="\e[0m"}"
  if [[ -n "${SSH_CONNECTION:-}" ]]; then
    box_hash; box_center "${BOLD}Notice:${NOCOLOR} You are running over SSH."
    box_center "The system will reboot after you press ENTER."; box_hash
  fi
  hbox "${BOLD}First Boot After Installation - Setup Instructions${NOCOLOR}"; box_center ""
  box_center "Once your system is rebooted ${BOLD}${YELLOW}with the CRT Script installed${NOCOLOR}, you must do the following:"
  box_center ""; box_center "1) Go to:  MAIN MENU -> SYSTEM SETTINGS -> HARDWARE"; box_center ""
  box_center "2) Set these values:"
  box_center "    ${BOLD}VIDEO OUTPUT:${NOCOLOR}  Set this to the correct connected output (there should only be one listed)."
  box_center "    ${BOLD}VIDEO MODE:${NOCOLOR}   Set this based on your chosen profile:"; box_center ""
  box_center "${BOLD}For 15kHz CRT Profiles${NOCOLOR}"; box_center "   640x480   ->  Boot_480i 1.0:0:0 15KHz 60Hz"
  box_center "   768x576   ->  Boot_576i 1.0:0:0 15KHz 50Hz"; box_center ""
  box_center "${BOLD}For 31kHz (VGA) Profiles${NOCOLOR}"; box_center "   640x480   ->  Boot_480i 1.0:0:0 31KHz 60Hz"
  box_center ""; box_center "[*] All profiles will have a ${BOLD}Boot_${NOCOLOR} prefix in the list."
  box_center "[*] Make sure the ${BOLD}Boot_${NOCOLOR} entry you select matches the ${BOLD}exact resolution${NOCOLOR} you picked during installation."
  box_center ""; box_hash; box_center ""; box_center "${GREEN}${BOLD}Press ENTER to reboot now...${NOCOLOR}"
  box_center ""; box_hash; echo; read -r; reboot
}
