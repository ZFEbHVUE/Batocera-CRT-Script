#!/bin/bash
# Batocera-CRT-Script v44 installer - entry point.
# The install steps are in ./v44/. Each one is sourced into this shell, in this order,
# so the variables and functions set by a step are seen by the next ones.
CRT_LOG=/dev/null
LOG_FILE=/dev/null
CRTD=/userdata/system/Batocera-CRT-Script
TCD=/userdata/system/logs/TYPE_OF_CARD_DRIVERS.info
V44_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)/v44"
[ -f "$V44_DIR/01_tui_helpers.sh" ] || V44_DIR="$CRTD/Batocera_ALLINONE/v44"
if [ ! -f "$V44_DIR/01_tui_helpers.sh" ]; then
  echo "Batocera-CRT-Script: install steps not found in $V44_DIR" >&2
  exit 1
fi

# Load a helper that must be a regular file. A missing file stops the install.
require_file() {
  __crt_file="$1"
  __crt_message="$2"
  if [ ! -f "$V44_DIR/$__crt_file" ] || [ -L "$V44_DIR/$__crt_file" ]; then
    printf '%s\n' "$__crt_message" >&2
    exit 1
  fi
  source "$V44_DIR/$__crt_file" || exit 1
}

# Source one step into this shell and record that it loaded.
# Pass required as the second argument to stop when that step fails to load.
source_step() {
  __crt_step="$1"
  __crt_check="${2:-}"
  if declare -F log_module_begin >/dev/null 2>&1; then log_module_begin "$__crt_step"; fi
  source "$V44_DIR/${__crt_step}.sh"
  __crt_source_rc=$?
  if declare -F log_module_end >/dev/null 2>&1; then log_module_end "$__crt_step" "$__crt_source_rc"; fi
  if [ "$__crt_check" = required ]; then source_ok "$__crt_step" "$__crt_source_rc"; fi
}

# No-op until log/events.sh loads and replaces this.
log_event() { :; }

require_file verify/preflight.sh 'CRT installer preflight helper missing or unsafe'
preflight "$V44_DIR" || exit 1

# New EDID, switchres.ini copy, and BootRes.log. Nothing is installed before confirm.
if [ ! -f "$V44_DIR/edid_hold.sh" ]; then
  printf '%s\n' 'CRT EDID hold missing; refusing unsafe install' >&2
  exit 1
fi
source "$V44_DIR/edid_hold.sh"
trap 'stage_discard' EXIT

# Diagnostic event log. Console tee output stays discarded.
if [ -f "$V44_DIR/log/events.sh" ] && [ ! -L "$V44_DIR/log/events.sh" ]; then
  source "$V44_DIR/log/events.sh"
  log_init "${LOG_DIR:-/userdata/system/logs}" || \
    printf '%s\n' 'CRT diagnostic log unavailable; terminal output remains active' >&2
fi
log_event INFO installer source_layout_preflight outcome passed count 32

if [ -f "$V44_DIR/log/diagnostics.sh" ]; then
  source "$V44_DIR/log/diagnostics.sh"
fi

require_file log/session.sh 'CRT session log missing or unsafe'
session_install_traps
require_file verify/writes.sh 'CRT write checks missing or unsafe'

source_step 01_tui_helpers
source_step 02_amd_helpers
source_step 03_final_message
set -u   # from here on, an unset variable stops the install
: "${PARSED_ENGINE:=}"; : "${PARSED_VERSION:=}"; : "${PCI_ADDR:=}"; : "${CARD_INDEX:=}"
source_step 04_backup_restore
source_step 05_version_check
source_step 06_dualboot_phase1
# Restore is loaded before routing because routing calls restore_all as it loads.
source_step 25_restore
source_step 07_install_routing
source_step 08_boot_custom
source_step 09_output_detection
source_step 10_welcome
source_step 23_install_review

while :; do
  source_step 11_graphics_card
  source_step 12_crt_output
  source_step 13_monitor_edid
  source_step 14_rotation
  source_step 15_vendor_defaults
  source_step 16_advanced_settings
  source_step 19_encoders_guncon
  review_crt_plan
  log_event INFO 23_install_review choice_recorded choice "${REVIEW_CHOICE:-unknown}"
  case "$REVIEW_CHOICE" in
    1) session_set_state applying
       if declare -F diag_context >/dev/null 2>&1; then diag_context || :; fi
       if declare -F log_confirmed_settings >/dev/null 2>&1; then log_confirmed_settings || :; fi
       break ;;
    2) if declare -F diag_event >/dev/null 2>&1; then diag_event 23_install_review review_flow edit requested || :; fi
       discard_unconfirmed_install_files
       continue ;;
    *) if declare -F diag_event >/dev/null 2>&1; then diag_event 23_install_review review_flow cancel requested || :; fi
       discard_unconfirmed_install_files
       session_note_cancel review_cancel
       box_center "Install cancelled. The boot partition was not changed."
       exit 0 ;;
  esac
done

if ! stage_commit "$Name_monitor_EDID" /lib/firmware/edid /userdata/system/logs/BootRes.log; then
  log_event ERROR 13_monitor_edid staged_commit_failed operation edid_bootres
  printf '%s\n' 'CRT install stopped: staged EDID/BootRes commit failed; boot files not changed.' >&2
  exit 1
fi
log_event INFO 13_monitor_edid staged_commit_verified operation edid_bootres
diag_run 09_output_detection xorg_monitor_write persist_10_monitor_conf
required_ok 09_output_detection xorg_monitor_write "$?"
if declare -F diag_probe >/dev/null 2>&1; then
  diag_probe 09_output_detection xorg_monitor_conf /etc/X11/xorg.conf.d/10-monitor.conf
fi

log_event INFO installer approved_apply_started operation videomodes
install_selected_videomodes
__vm_rc=$?
if [ "$__vm_rc" -ne 0 ]; then
  log_event ERROR installer approved_apply_failed operation videomodes rc "$__vm_rc"
  exit 1
fi
log_event INFO installer approved_apply_returned operation videomodes outcome ok

source_step 17_boot_config required
source_step 18_system_files required
diag_run 19_encoders_guncon encoder_apply apply_encoder_selection
required_ok 19_encoders_guncon encoder_apply "$?"
stage_discard
source_step 20_crt_tools required
source_step 21_event_scripts required
source_step 22_batocera_conf required
source_step 24_finish required
