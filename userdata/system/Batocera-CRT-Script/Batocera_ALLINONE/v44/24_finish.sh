# Batocera-CRT-Script v44 - step 24: finish
# boot-custom.sh, Phase 2 overlay save, then reboot (or power-off for dual-boot).
# Read-only install check. Source only after Confirm.
if [ ! -f "$V44_DIR/verify/install.sh" ] || [ -L "$V44_DIR/verify/install.sh" ]; then
  err_box "Installer verification helper missing or unsafe; installation remains pending."
  exit 1
fi
source "$V44_DIR/verify/install.sh" || exit 1
# Compare the overlay image before and after the save. The payload read never writes it.
if [ ! -f "$V44_DIR/verify/overlay.sh" ] || [ -L "$V44_DIR/verify/overlay.sh" ]; then
  err_box "Overlay verifier missing or unsafe; installation remains pending."
  exit 1
fi
source "$V44_DIR/verify/overlay.sh" || exit 1
if ! chmod 755 "$file_BatoceraConf"; then
  verify_abort batocera_conf_permissions PRE_SAVE || exit 1
fi
if ! maybe_install_boot_custom_sh; then
  verify_abort boot_custom_install PRE_SAVE || exit 1
fi
if ! verify_all; then
  verify_abort install_content_pre_save PRE_SAVE || exit 1
fi
# Verify optional-but-required boot-custom after verify_all resets its counters.
if [ "${VERIFY_BOOT_CUSTOM_REQUIRED:-0}" = 1 ]; then
  verify_copy 'boot-custom required' UsrBin_configs/boot-custom.sh /boot/boot-custom.sh yes
  if (( VERIFY_FAILS > 0 )); then verify_abort boot_custom_readback PRE_SAVE || exit 1; fi
fi
verify_write_report PRE_SAVE PENDING || { verify_abort verification_report PRE_SAVE || :; exit 1; }
verify_emit_summary PRE_SAVE PENDING
# Fingerprint before invoking either existing saver, after PRE_SAVE validation.
if ! overlay_before; then verify_abort overlay_freshness_baseline SAVE || exit 1; fi
# Step 20 saves before step 22 updates batocera.conf. In a single-boot install,
# repeat the existing native save utility only after final required configuration.
if [ "$IS_PHASE2" != true ]; then
  if ! command -v batocera-save-overlay >/dev/null 2>&1; then
    verify_abort native_saver_missing SAVE || exit 1
  fi
  if declare -F log_run >/dev/null 2>&1; then
    log_run 24_finish final_native_overlay_save batocera-save-overlay
    verify_save_rc=$?
  else
    batocera-save-overlay
    verify_save_rc=$?
  fi
  if [ "$verify_save_rc" -ne 0 ]; then
    verify_abort native_overlay_save_failed SAVE || exit 1
  fi
fi
if [ "$IS_PHASE2" = true ]; then
  hbox "Phase 2: Saving CRT overlay and finalizing dual-boot..."; box_empty
  crt_overlay="${CRT_SCRIPT_DIR}/batocera-save-crt-overlay"
  if [ ! -f "$crt_overlay" ] || [ -L "$crt_overlay" ] || [ ! -x "$crt_overlay" ]; then
    if declare -F log_event >/dev/null 2>&1; then
      log_event ERROR 24_finish crt_overlay_save outcome failed reason writer_missing_or_unsafe || :
    fi
    verify_abort phase2_overlay_saver_missing SAVE || :
    err_box "CRT overlay saver missing or unsafe. Phase 2 remains pending."
    exit 1
  fi
  box_center "Saving CRT configuration overlay..."
  if declare -F log_run >/dev/null 2>&1; then
    log_run 24_finish crt_overlay_save "$crt_overlay"
    crt_overlay_save_rc=$?
  else
    "$crt_overlay"
    crt_overlay_save_rc=$?
  fi
  if [ "$crt_overlay_save_rc" -ne 0 ]; then
    if declare -F log_event >/dev/null 2>&1; then
      log_event ERROR 24_finish phase2_crt_overlay_save outcome failed rc "$crt_overlay_save_rc" || :
    fi
    verify_abort phase2_crt_overlay_save_failed SAVE || :
    err_box "CRT overlay save failed (rc=$crt_overlay_save_rc). Phase 2 remains pending."
    exit "$crt_overlay_save_rc"
  fi
  if declare -F log_event >/dev/null 2>&1; then
    log_event INFO 24_finish phase2_crt_overlay_save outcome ok rc 0 || :
  fi
  # Verify installed content again after saver, plus expected overlay output.
  if ! verify_all; then verify_abort install_content_post_save POST_SAVE || exit 1; fi
  if [ "${VERIFY_BOOT_CUSTOM_REQUIRED:-0}" = 1 ]; then
    verify_copy 'boot-custom required' UsrBin_configs/boot-custom.sh /boot/boot-custom.sh yes
  fi
  verify_overlay_check || :
  overlay_after || :
  if declare -F payload_probe >/dev/null 2>&1; then
    payload_probe || :
  else
    VERIFY_LINES+=("UNVERIFIED | Overlay image payload | overlay payload check not available")
  fi
  if (( VERIFY_FAILS > 0 )); then
    if [[ "${OVERLAY_FRESHNESS:-}" == unchanged ]]; then
      verify_abort overlay_freshness_unproven POST_SAVE || exit 1
    else
      verify_abort overlay_or_content_post_save POST_SAVE || exit 1
    fi
  fi
  verify_write_report POST_SAVE SAVE_EXIT_0 || { verify_abort verification_report POST_SAVE || :; exit 1; }
  verify_emit_summary POST_SAVE SAVE_EXIT_0
  if ! rm -f -- "$PHASE_FLAG"; then
    if declare -F log_event >/dev/null 2>&1; then
      log_event ERROR 24_finish phase2_marker_clear outcome failed || :
    fi
    verify_abort phase2_marker_clear_failed FINAL || :
    err_box "CRT overlay saved but Phase 2 marker could not be cleared. Installation remains pending."
    exit 1
  fi
  if declare -F log_event >/dev/null 2>&1; then
    log_event INFO 24_finish phase2_marker_clear outcome ok || :
  fi
  box_center "Phase flag removed."
  box_center "CRT remains the default boot entry for first-boot setup."; box_empty; ok_box "Dual-boot Phase 2 complete."
fi
if [ "$IS_PHASE2" != true ]; then
  if ! verify_all; then verify_abort install_content_post_save POST_SAVE || exit 1; fi
  if [ "${VERIFY_BOOT_CUSTOM_REQUIRED:-0}" = 1 ]; then
    verify_copy 'boot-custom required' UsrBin_configs/boot-custom.sh /boot/boot-custom.sh yes
  fi
  verify_overlay_check || :
  overlay_after || :
  if declare -F payload_probe >/dev/null 2>&1; then
    payload_probe || :
  else
    VERIFY_LINES+=("UNVERIFIED | Overlay image payload | overlay payload check not available")
  fi
  if (( VERIFY_FAILS > 0 )); then
    if [[ "${OVERLAY_FRESHNESS:-}" == unchanged ]]; then
      verify_abort overlay_freshness_unproven POST_SAVE || exit 1
    else
      verify_abort overlay_or_content_post_save POST_SAVE || exit 1
    fi
  fi
  verify_write_report POST_SAVE SAVE_EXIT_0 || { verify_abort verification_report POST_SAVE || :; exit 1; }
  verify_emit_summary POST_SAVE SAVE_EXIT_0
fi
# Log before any power-off/reboot call can terminate the process. This is a
# handoff, not an assertion that all installation files passed verification.
if declare -F diag_pre_shutdown >/dev/null 2>&1; then
  if [ "$IS_PHASE2" = true ]; then
    diag_pre_shutdown phase2 || :
  else
    diag_pre_shutdown singleboot || :
  fi
fi
if [ "$IS_PHASE2" = true ]; then
  hbox "${BOLD}Dual-Boot Phase 2 Installation Complete${NOCOLOR}"; box_center ""
  box_center "Please ${BOLD}${YELLOW}power off${NOCOLOR} your system and then power it back on."
  box_center "Do ${BOLD}NOT${NOCOLOR} use the reboot option — a full power cycle is required"
  box_center "so the CRT kernel and overlay load correctly."; box_center ""; box_hash; box_center ""
  box_center "${GREEN}${BOLD}Press ENTER to shut down now...${NOCOLOR}"; box_center ""; box_hash; echo; read -r
  _dualboot_installer_poweroff
  session_power_rc=$?
  if declare -F session_shutdown_returned >/dev/null 2>&1; then
    session_shutdown_returned phase2 "$session_power_rc" || :
  fi
elif declare -f show_first_boot_instructions_and_reboot >/dev/null 2>&1; then
  show_first_boot_instructions_and_reboot
  session_power_rc=$?
  if declare -F session_shutdown_returned >/dev/null 2>&1; then
    session_shutdown_returned singleboot "$session_power_rc" || :
  fi
else
  echo -e "${GREEN}${BOLD}Setup complete. Press ENTER to reboot...${NOCOLOR}"; read -r
  if command -v systemctl >/dev/null 2>&1; then
    systemctl reboot
    session_power_rc=$?
    if declare -F session_shutdown_returned >/dev/null 2>&1; then
      session_shutdown_returned singleboot "$session_power_rc" || :
    fi
  else
    sync; reboot
    session_power_rc=$?
    if declare -F session_shutdown_returned >/dev/null 2>&1; then
      session_shutdown_returned singleboot "$session_power_rc" || :
    fi
  fi
fi
# The old event was unreachable when shutdown/reboot ended Bash.
exit 0
