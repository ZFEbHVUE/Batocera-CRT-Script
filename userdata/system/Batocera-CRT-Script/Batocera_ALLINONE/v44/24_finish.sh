# Batocera-CRT-Script v44 - step 24: finish
# boot-custom.sh, Phase 2 overlay save, then reboot (or power-off for dual-boot).
chmod 755 "$file_BatoceraConf"; maybe_install_boot_custom_sh
if [ "$IS_PHASE2" = true ]; then
  hbox "Phase 2: Saving CRT overlay and finalizing dual-boot..."; box_empty
  crt_overlay="${CRT_SCRIPT_DIR}/batocera-save-crt-overlay"
  if [ -x "$crt_overlay" ]; then
    box_center "Saving CRT configuration overlay..."
    if declare -F crt59_run >/dev/null 2>&1; then
      crt59_run 24_finish crt_overlay_save "$crt_overlay" || err_box "Warning: overlay save returned non-zero"
    else "$crt_overlay" || err_box "Warning: overlay save returned non-zero"; fi
  else
    if declare -F crt59_event >/dev/null 2>&1; then crt59_event ERROR 24_finish crt_overlay_save outcome missing || :; fi
    err_box "batocera-save-crt-overlay not found — deploy may have been skipped"
  fi
  rm -f "$PHASE_FLAG"; box_center "Phase flag removed."
  box_center "CRT remains the default boot entry for first-boot setup."; box_empty; ok_box "Dual-boot Phase 2 complete."
fi
if [ "$IS_PHASE2" = true ]; then
  hbox "${BOLD}Dual-Boot Phase 2 Installation Complete${NOCOLOR}"; box_center ""
  box_center "Please ${BOLD}${YELLOW}power off${NOCOLOR} your system and then power it back on."
  box_center "Do ${BOLD}NOT${NOCOLOR} use the reboot option — a full power cycle is required"
  box_center "so the CRT kernel and overlay load correctly."; box_center ""; box_hash; box_center ""
  box_center "${GREEN}${BOLD}Press ENTER to shut down now...${NOCOLOR}"; box_center ""; box_hash; echo; read -r
  _dualboot_installer_poweroff
elif declare -f show_first_boot_instructions_and_reboot >/dev/null 2>&1; then
  show_first_boot_instructions_and_reboot
else
  echo -e "${GREEN}${BOLD}Setup complete. Press ENTER to reboot...${NOCOLOR}"; read -r
  if command -v systemctl >/dev/null 2>&1; then
    systemctl reboot
  else
    sync; reboot
  fi
fi
if declare -F crt59_event >/dev/null 2>&1; then
  crt59_event WARN 24_finish finish_reached outcome unverified reason legacy_success_gate || :
fi
exit 0
