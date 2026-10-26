# -----------------------------------------------------------------------------
# Finalize: install /boot/boot-custom.sh when not on NVIDIA proprietary
# -----------------------------------------------------------------------------
maybe_install_boot_custom_sh

# -----------------------------------------------------------------------------
# Phase 2 finalization: save CRT overlay, delete phase flag, reset boot default
# (only runs when the script entered via Phase 2 routing)
# -----------------------------------------------------------------------------
if [ "$IS_PHASE2" = true ]; then
  box_hash
  box_center "Phase 2: Saving CRT overlay and finalizing dual-boot..."
  box_hash
  box_empty

  # Save overlay so CRT configs persist across reboots
  crt_overlay="${CRT_SCRIPT_DIR}/batocera-save-crt-overlay"
  if [ -x "$crt_overlay" ]; then
    box_center "Saving CRT configuration overlay..."
    "$crt_overlay" || err_box "Warning: overlay save returned non-zero"
  else
    err_box "batocera-save-crt-overlay not found — deploy may have been skipped"
  fi

  # Delete phase flag so Phase 2 doesn't re-trigger
  rm -f "$PHASE_FLAG"
  box_center "Phase flag removed."
  box_center "CRT remains the default boot entry for first-boot setup."

  box_empty
  ok_box "Dual-boot Phase 2 complete."
fi

# -----------------------------------------------------------------------------
# Show final first-boot instructions and reboot / power-cycle prompt
# (Requires: box_hash, box_center, and color vars defined earlier)
# -----------------------------------------------------------------------------
if [ "$IS_PHASE2" = true ]; then
  # Dual-boot: do NOT reboot — user must power cycle to load the CRT kernel
  box_hash
  box_center "${BOLD}Dual-Boot Phase 2 Installation Complete${NOCOLOR}"
  box_hash
  box_center ""
  box_center "Please ${BOLD}${YELLOW}power off${NOCOLOR} your system and then power it back on."
  box_center "Do ${BOLD}NOT${NOCOLOR} use the reboot option — a full power cycle is required"
  box_center "so the CRT kernel and overlay load correctly."
  box_center ""
  box_hash
  box_center ""
  box_center "${GREEN}${BOLD}Press ENTER to shut down now...${NOCOLOR}"
  box_center ""
  box_hash
  echo
  read -r
  _dualboot_installer_poweroff
elif declare -f show_first_boot_instructions_and_reboot >/dev/null 2>&1; then
  show_first_boot_instructions_and_reboot
else
  # Fallback (shouldn't happen): print a minimal message, then reboot
  echo -e "${GREEN}${BOLD}Setup complete. Press ENTER to reboot...${NOCOLOR}"
  read -r
  if command -v systemctl >/dev/null 2>&1; then
    systemctl reboot
  else
    sync
    reboot
  fi
fi

exit 0


