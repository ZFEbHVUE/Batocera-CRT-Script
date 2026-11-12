#!/bin/bash
# Batocera-CRT-Script v44 installer - entry point.
# The install steps are in ./v44/. Each one is sourced into this shell, in this order,
# so the variables and functions set by a step are seen by the next ones.
CRT_LOG=/dev/null LOG_FILE=/dev/null CRTD=/userdata/system/Batocera-CRT-Script TCD=/userdata/system/logs/TYPE_OF_CARD_DRIVERS.info
V44_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)/v44"
[ -f "$V44_DIR/01_tui_helpers.sh" ] || V44_DIR="$CRTD/Batocera_ALLINONE/v44"
if [ ! -f "$V44_DIR/01_tui_helpers.sh" ]; then echo "Batocera-CRT-Script: install steps not found in $V44_DIR" >&2; exit 1; fi
# Phase 59: one structured diagnostic log. The old console transcript is discarded.
if [ -f "$V44_DIR/crt59_logger.sh" ] && [ ! -L "$V44_DIR/crt59_logger.sh" ]; then
  source "$V44_DIR/crt59_logger.sh"
  crt59_init "${CRT59_LOG_DIR:-/userdata/system/logs}" || \
    printf '%s\n' 'CRT diagnostic log unavailable; terminal output remains active' >&2
fi
if declare -F crt59_module_begin >/dev/null 2>&1; then crt59_module_begin 01_tui_helpers; fi
source "$V44_DIR/01_tui_helpers.sh"
__crt59_source_rc=$?
if declare -F crt59_module_end >/dev/null 2>&1; then crt59_module_end 01_tui_helpers "$__crt59_source_rc"; fi
if declare -F crt59_module_begin >/dev/null 2>&1; then crt59_module_begin 02_amd_helpers; fi
source "$V44_DIR/02_amd_helpers.sh"
__crt59_source_rc=$?
if declare -F crt59_module_end >/dev/null 2>&1; then crt59_module_end 02_amd_helpers "$__crt59_source_rc"; fi
if declare -F crt59_module_begin >/dev/null 2>&1; then crt59_module_begin 03_final_message; fi
source "$V44_DIR/03_final_message.sh"
__crt59_source_rc=$?
if declare -F crt59_module_end >/dev/null 2>&1; then crt59_module_end 03_final_message "$__crt59_source_rc"; fi
set -u   # from here on, an unset variable stops the install (as in the original script)
: "${PARSED_ENGINE:=}"; : "${PARSED_VERSION:=}"; : "${PCI_ADDR:=}"; : "${CARD_INDEX:=}"
if declare -F crt59_module_begin >/dev/null 2>&1; then crt59_module_begin 04_backup_restore; fi
source "$V44_DIR/04_backup_restore.sh"
__crt59_source_rc=$?
if declare -F crt59_module_end >/dev/null 2>&1; then crt59_module_end 04_backup_restore "$__crt59_source_rc"; fi
if declare -F crt59_module_begin >/dev/null 2>&1; then crt59_module_begin 05_version_check; fi
source "$V44_DIR/05_version_check.sh"
__crt59_source_rc=$?
if declare -F crt59_module_end >/dev/null 2>&1; then crt59_module_end 05_version_check "$__crt59_source_rc"; fi
if declare -F crt59_module_begin >/dev/null 2>&1; then crt59_module_begin 06_dualboot_phase1; fi
source "$V44_DIR/06_dualboot_phase1.sh"
__crt59_source_rc=$?
if declare -F crt59_module_end >/dev/null 2>&1; then crt59_module_end 06_dualboot_phase1 "$__crt59_source_rc"; fi
# Step 25 is sourced here, before routing, because routing calls restore_all as it loads.
if declare -F crt59_module_begin >/dev/null 2>&1; then crt59_module_begin 25_restore; fi
source "$V44_DIR/25_restore.sh"
__crt59_source_rc=$?
if declare -F crt59_module_end >/dev/null 2>&1; then crt59_module_end 25_restore "$__crt59_source_rc"; fi
if declare -F crt59_module_begin >/dev/null 2>&1; then crt59_module_begin 07_install_routing; fi
source "$V44_DIR/07_install_routing.sh"
__crt59_source_rc=$?
if declare -F crt59_module_end >/dev/null 2>&1; then crt59_module_end 07_install_routing "$__crt59_source_rc"; fi
if declare -F crt59_module_begin >/dev/null 2>&1; then crt59_module_begin 08_boot_custom; fi
source "$V44_DIR/08_boot_custom.sh"
__crt59_source_rc=$?
if declare -F crt59_module_end >/dev/null 2>&1; then crt59_module_end 08_boot_custom "$__crt59_source_rc"; fi
if declare -F crt59_module_begin >/dev/null 2>&1; then crt59_module_begin 09_output_detection; fi
source "$V44_DIR/09_output_detection.sh"
__crt59_source_rc=$?
if declare -F crt59_module_end >/dev/null 2>&1; then crt59_module_end 09_output_detection "$__crt59_source_rc"; fi
if declare -F crt59_module_begin >/dev/null 2>&1; then crt59_module_begin 10_welcome; fi
source "$V44_DIR/10_welcome.sh"
__crt59_source_rc=$?
if declare -F crt59_module_end >/dev/null 2>&1; then crt59_module_end 10_welcome "$__crt59_source_rc"; fi
if declare -F crt59_module_begin >/dev/null 2>&1; then crt59_module_begin 23_install_review; fi
source "$V44_DIR/23_install_review.sh"
__crt59_source_rc=$?
if declare -F crt59_module_end >/dev/null 2>&1; then crt59_module_end 23_install_review "$__crt59_source_rc"; fi
while :; do
  if declare -F crt59_module_begin >/dev/null 2>&1; then crt59_module_begin 11_graphics_card; fi
source "$V44_DIR/11_graphics_card.sh"
__crt59_source_rc=$?
if declare -F crt59_module_end >/dev/null 2>&1; then crt59_module_end 11_graphics_card "$__crt59_source_rc"; fi
  if declare -F crt59_module_begin >/dev/null 2>&1; then crt59_module_begin 12_crt_output; fi
source "$V44_DIR/12_crt_output.sh"
__crt59_source_rc=$?
if declare -F crt59_module_end >/dev/null 2>&1; then crt59_module_end 12_crt_output "$__crt59_source_rc"; fi
  if declare -F crt59_module_begin >/dev/null 2>&1; then crt59_module_begin 13_monitor_edid; fi
source "$V44_DIR/13_monitor_edid.sh"
__crt59_source_rc=$?
if declare -F crt59_module_end >/dev/null 2>&1; then crt59_module_end 13_monitor_edid "$__crt59_source_rc"; fi
  if declare -F crt59_module_begin >/dev/null 2>&1; then crt59_module_begin 14_rotation; fi
source "$V44_DIR/14_rotation.sh"
__crt59_source_rc=$?
if declare -F crt59_module_end >/dev/null 2>&1; then crt59_module_end 14_rotation "$__crt59_source_rc"; fi
  if declare -F crt59_module_begin >/dev/null 2>&1; then crt59_module_begin 15_vendor_defaults; fi
source "$V44_DIR/15_vendor_defaults.sh"
__crt59_source_rc=$?
if declare -F crt59_module_end >/dev/null 2>&1; then crt59_module_end 15_vendor_defaults "$__crt59_source_rc"; fi
  if declare -F crt59_module_begin >/dev/null 2>&1; then crt59_module_begin 16_advanced_settings; fi
source "$V44_DIR/16_advanced_settings.sh"
__crt59_source_rc=$?
if declare -F crt59_module_end >/dev/null 2>&1; then crt59_module_end 16_advanced_settings "$__crt59_source_rc"; fi
  if declare -F crt59_module_begin >/dev/null 2>&1; then crt59_module_begin 19_encoders_guncon; fi
source "$V44_DIR/19_encoders_guncon.sh"
__crt59_source_rc=$?
if declare -F crt59_module_end >/dev/null 2>&1; then crt59_module_end 19_encoders_guncon "$__crt59_source_rc"; fi
  review_crt_plan
  if declare -F crt59_event >/dev/null 2>&1; then
    crt59_event INFO 23_install_review choice_recorded choice "${REVIEW_CHOICE:-unknown}" || :
  fi
  case "$REVIEW_CHOICE" in
    1) if declare -F crt59_log_confirmed_settings >/dev/null 2>&1; then crt59_log_confirmed_settings; fi; break ;;
    2) discard_unconfirmed_install_files; continue ;;
    *) discard_unconfirmed_install_files
       box_center "Install cancelled. The boot partition was not changed."; exit 0 ;;
  esac
done
persist_10_monitor_conf
if declare -F crt59_event >/dev/null 2>&1; then crt59_event INFO installer approved_apply_started operation videomodes || :; fi
install_selected_videomodes
__crt59_vm_rc=$?
if [ "$__crt59_vm_rc" -ne 0 ]; then
  if declare -F crt59_event >/dev/null 2>&1; then crt59_event ERROR installer approved_apply_failed operation videomodes rc "$__crt59_vm_rc" || :; fi
  exit 1
fi
if declare -F crt59_event >/dev/null 2>&1; then crt59_event INFO installer approved_apply_returned operation videomodes outcome ok || :; fi
if declare -F crt59_module_begin >/dev/null 2>&1; then crt59_module_begin 17_boot_config; fi
source "$V44_DIR/17_boot_config.sh"
__crt59_source_rc=$?
if declare -F crt59_module_end >/dev/null 2>&1; then crt59_module_end 17_boot_config "$__crt59_source_rc"; fi
if declare -F crt59_module_begin >/dev/null 2>&1; then crt59_module_begin 18_system_files; fi
source "$V44_DIR/18_system_files.sh"
__crt59_source_rc=$?
if declare -F crt59_module_end >/dev/null 2>&1; then crt59_module_end 18_system_files "$__crt59_source_rc"; fi
apply_encoder_selection
if declare -F crt59_module_begin >/dev/null 2>&1; then crt59_module_begin 20_crt_tools; fi
source "$V44_DIR/20_crt_tools.sh"
__crt59_source_rc=$?
if declare -F crt59_module_end >/dev/null 2>&1; then crt59_module_end 20_crt_tools "$__crt59_source_rc"; fi
if declare -F crt59_module_begin >/dev/null 2>&1; then crt59_module_begin 21_event_scripts; fi
source "$V44_DIR/21_event_scripts.sh"
__crt59_source_rc=$?
if declare -F crt59_module_end >/dev/null 2>&1; then crt59_module_end 21_event_scripts "$__crt59_source_rc"; fi
if declare -F crt59_module_begin >/dev/null 2>&1; then crt59_module_begin 22_batocera_conf; fi
source "$V44_DIR/22_batocera_conf.sh"
__crt59_source_rc=$?
if declare -F crt59_module_end >/dev/null 2>&1; then crt59_module_end 22_batocera_conf "$__crt59_source_rc"; fi
if declare -F crt59_module_begin >/dev/null 2>&1; then crt59_module_begin 24_finish; fi
source "$V44_DIR/24_finish.sh"
__crt59_source_rc=$?
if declare -F crt59_module_end >/dev/null 2>&1; then crt59_module_end 24_finish "$__crt59_source_rc"; fi
