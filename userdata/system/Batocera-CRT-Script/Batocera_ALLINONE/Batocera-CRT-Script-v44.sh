#!/bin/bash
# Batocera-CRT-Script v44 installer - entry point.
# The install steps are in ./v44/. Each one is sourced into this shell, in this order,
# so the variables and functions set by a step are seen by the next ones.
CRT_LOG=/userdata/system/logs/BUILD_15KHz_Batocera.log CRTD=/userdata/system/Batocera-CRT-Script TCD=/userdata/system/logs/TYPE_OF_CARD_DRIVERS.info
V44_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)/v44"
[ -f "$V44_DIR/01_tui_helpers.sh" ] || V44_DIR="$CRTD/Batocera_ALLINONE/v44"
if [ ! -f "$V44_DIR/01_tui_helpers.sh" ]; then echo "Batocera-CRT-Script: install steps not found in $V44_DIR" >&2; exit 1; fi
source "$V44_DIR/01_tui_helpers.sh"
source "$V44_DIR/02_amd_helpers.sh"
source "$V44_DIR/03_final_message.sh"
set -u   # from here on, an unset variable stops the install (as in the original script)
: "${PARSED_ENGINE:=}"; : "${PARSED_VERSION:=}"; : "${PCI_ADDR:=}"; : "${CARD_INDEX:=}"
source "$V44_DIR/04_backup_restore.sh"
source "$V44_DIR/05_version_check.sh"
source "$V44_DIR/06_dualboot_phase1.sh"
source "$V44_DIR/07_install_routing.sh"
source "$V44_DIR/08_boot_custom.sh"
source "$V44_DIR/09_output_detection.sh"
source "$V44_DIR/10_welcome.sh"
source "$V44_DIR/11_graphics_card.sh"
source "$V44_DIR/12_crt_output.sh"
source "$V44_DIR/13_monitor_edid.sh"
source "$V44_DIR/14_rotation.sh"
source "$V44_DIR/15_vendor_defaults.sh"
source "$V44_DIR/16_advanced_settings.sh"
source "$V44_DIR/17_boot_config.sh"
source "$V44_DIR/18_system_files.sh"
source "$V44_DIR/19_encoders_guncon.sh"
source "$V44_DIR/20_crt_tools.sh"
source "$V44_DIR/21_event_scripts.sh"
source "$V44_DIR/22_batocera_conf.sh"
source "$V44_DIR/23_finish.sh"
