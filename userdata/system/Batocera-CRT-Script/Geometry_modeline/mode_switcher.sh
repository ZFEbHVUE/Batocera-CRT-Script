#!/bin/bash

#######################################################################################
# HD/CRT Mode Switcher
# 
# This script allows users to switch between HD Mode (standard Batocera) and
# CRT Mode (CRT Script installed) configurations.
#
# Version: 1.0.0
# Batocera Version: v42+
#######################################################################################

set +e  # Don't exit on error, we handle errors manually

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NOCOLOR='\033[0m'

# Dialog dark theme - use permanent config file
export DIALOGRC="/userdata/system/Batocera-CRT-Script/Geometry_modeline/dialogrc_dark"

# Script directories
SCRIPT_DIR="/userdata/system/Batocera-CRT-Script"
MODE_BACKUP_DIR="/userdata/Batocera-CRT-Script-Backup/mode_backups"
CRT_BACKUP_DIR="/userdata/Batocera-CRT-Script-Backup/BACKUP"
CRT_BACKUP_CHECK="${CRT_BACKUP_DIR%/*}/backup.file"

# Log file
LOG_FILE="/userdata/system/logs/BUILD_15KHz_Batocera.log"

# First run flag file
FIRST_RUN_FLAG="${SCRIPT_DIR}/Geometry_modeline/.mode_switcher_first_run"

# Python path - auto-detect version
PYTHON_VERSION=$(python3 --version 2>/dev/null | cut -d' ' -f2 | cut -d'.' -f1,2 || echo "3.12")
PYTHON_PATH="/usr/lib/python${PYTHON_VERSION}/site-packages/configgen"


#######################################################################################
# Load Modules
#######################################################################################

MODULES_DIR="${SCRIPT_DIR}/Geometry_modeline/mode_switcher_modules"

# Source all modules in order
if [ -d "$MODULES_DIR" ]; then
    source "${MODULES_DIR}/01_mode_detection.sh"
    source "${MODULES_DIR}/02_hd_output_selection.sh"
    source "${MODULES_DIR}/03_backup_restore.sh"
    source "${MODULES_DIR}/04_user_interface.sh"
else
    echo "Error: Modules directory not found: $MODULES_DIR" >&2
    exit 1
fi

#######################################################################################
# First Run Warning
#######################################################################################

# Function: show_first_run_warning
# Purpose: Display critical warning on first run only
# Returns: 0 if user acknowledges, 1 if cancelled
show_first_run_warning() {
    # Check if this is the first run
    if [ -f "$FIRST_RUN_FLAG" ]; then
        return 0  # Not first run, skip warning
    fi
    
    # Show the warning dialog with ASCII symbols - yellow text with red WARNING
    dialog --title "*** WARNING ***" \
           --backtitle "*** CRITICAL SAFETY WARNING ***" \
           --colors \
           --yes-label "I UNDERSTAND" \
           --no-label "EXIT" \
           --yesno "\n\Z3\Zb***  CRITICAL \Z1\ZbWARNING\Z3\Zb  ***\Zn\n\n\Z3\ZbA CRT MONITOR MUST NEVER BE TURNED ON DURING HD MODE!\Zn\n\n\Z3\ZbWE ARE NOT RESPONSIBLE FOR DAMAGE.\Zn\n\n\Z3\ZbKNOW YOUR GEAR.\Zn\n\n\Z3\ZbHIGH FREQUENCIES DURING HD MODE CAN PERMANENTLY DAMAGE YOUR CRT MONITOR!\Zn\n\n\Z3\ZbONLY TURN ON YOUR CRT MONITOR WHEN IN CRT MODE AND AFTER BATOCERA HAS FULLY BOOTED.\Zn\n\n\Z3\ZbUSE THIS TOOL AT YOUR OWN RISK.\Zn" \
           20 75
    
    local result=$?
    
    if [ $result -eq 0 ]; then
        # User acknowledged - create flag file so warning won't show again
        touch "$FIRST_RUN_FLAG"
        return 0
    else
        # User chose to exit
        return 1
    fi
}

#######################################################################################
# Main Execution
#######################################################################################

main() {
    # Show first-run warning if this is the first time
    if ! show_first_run_warning; then
        # User chose to exit from warning
        exit 0
    fi
    
    # Check if CRT Script is installed
    if ! check_crt_script_installed; then
        dialog --title "Error" \
               --backtitle "HD/CRT Mode Switcher" \
               --msgbox "CRT Script is not installed.\n\nMode Switcher is only available after CRT Script installation." \
               10 50
        exit 1
    fi
    
    # Create backup directories if they don't exist
    mkdir -p "$MODE_BACKUP_DIR"
    
    # Main loop
    while true; do
        # Step 1: Show main menu
        choice=$(show_main_menu)
        exit_code=$?
        
        if [ $exit_code -ne 0 ]; then
            # User cancelled
            exit 0
        fi
        
        # Determine target mode
        local current_mode=$(detect_current_mode)
        local target_mode=""
        
        case "$choice" in
            "switch_crt")
                target_mode="crt"
                ;;
            "switch_hd")
                target_mode="hd"
                ;;
            *)
                continue
                ;;
        esac
        
        # Skip if already in target mode
        if [ "$current_mode" = "$target_mode" ]; then
            dialog --title "Information" \
                   --backtitle "HD/CRT Mode Switcher" \
                   --msgbox "System is already in $(get_mode_display_name "$target_mode")." \
                   8 50
            continue
        fi
        
        # Run the mode switch UI (handles all config checks and selections)
        if ! run_mode_switch_ui "$target_mode"; then
            # User cancelled
            continue
        fi
        
        # Step 2: First confirmation
        if ! confirm_mode_switch "$target_mode"; then
            continue
        fi
        
        # Step 3: Safety disclaimer (mode-specific)
        if ! show_safety_disclaimer "$target_mode"; then
            continue
        fi
        
        # Perform backup and restore
        show_progress "Backing up current mode..."
        if ! backup_mode_files "$current_mode"; then
            show_error_message "Failed to backup current mode settings."
            continue
        fi
        
        show_progress "Restoring target mode..."
        if ! restore_mode_files "$target_mode"; then
            show_error_message "Failed to restore target mode settings."
            continue
        fi
        
        # Step 4: Success message
        show_success_message "$target_mode"
        
        # CRITICAL: Final verification RIGHT BEFORE REBOOT
        # This is the absolute last chance to ensure es_systems_crt.cfg is correct
        echo "[$(date +"%H:%M:%S")]: FINAL PRE-REBOOT VERIFICATION..." >> "$LOG_FILE"
        if [ -f "/userdata/system/Batocera-CRT-Script/Geometry_modeline/es_systems_crt.cfg" ]; then
            mkdir -p /userdata/system/configs/emulationstation 2>/dev/null || true
            cp /userdata/system/Batocera-CRT-Script/Geometry_modeline/es_systems_crt.cfg /userdata/system/configs/emulationstation/es_systems_crt.cfg 2>/dev/null || true
            chmod 644 /userdata/system/configs/emulationstation/es_systems_crt.cfg 2>/dev/null || true
            # Touch the file to update timestamp (forces EmulationStation to see it as changed)
            touch /userdata/system/configs/emulationstation/es_systems_crt.cfg 2>/dev/null || true
            sync 2>/dev/null || true
            # Double sync to ensure everything is written
            sync 2>/dev/null || true
            if grep -q "emulatorlauncher" /userdata/system/configs/emulationstation/es_systems_crt.cfg 2>/dev/null; then
                echo "[$(date +"%H:%M:%S")]: FINAL VERIFICATION PASSED: es_systems_crt.cfg is correct" >> "$LOG_FILE"
            else
                echo "[$(date +"%H:%M:%S")]: FINAL VERIFICATION FAILED: es_systems_crt.cfg is INCORRECT!" >> "$LOG_FILE"
            fi
        fi
        
        # Small delay to ensure all file operations complete before reboot
        sleep 2
        
        # Reboot
        reboot
    done
}

# Run main function
main "$@"
