#######################################################################################
# Module 05: User Interface
#######################################################################################

# Function: show_main_menu
# Purpose: Display main menu and get user selection (Flow Step 1)
# Returns: User selection string or empty on Cancel
show_main_menu() {
    local current_mode=$(detect_current_mode)
    local mode_display=$(get_mode_display_name "$current_mode")
    
    # Only show the option to switch to the OTHER mode
    if [ "$current_mode" = "crt" ]; then
        # In CRT Mode - only show option to switch to HD Mode
        dialog --title "HD/CRT Mode Switcher" \
               --backtitle "HD/CRT Mode Switcher" \
               --ok-label "Proceed" \
               --cancel-label "Cancel" \
               --menu "Current Mode: $mode_display" \
               10 50 1 \
               "switch_hd" "Switch to HD Mode" \
               3>&1 1>&2 2>&3
    else
        # In HD Mode - only show option to switch to CRT Mode
        dialog --title "HD/CRT Mode Switcher" \
               --backtitle "HD/CRT Mode Switcher" \
               --ok-label "Proceed" \
               --cancel-label "Cancel" \
               --menu "Current Mode: $mode_display" \
               10 50 1 \
               "switch_crt" "Switch to CRT Mode" \
               3>&1 1>&2 2>&3
    fi
}

# Function: confirm_mode_switch
# Purpose: Step 2 - First confirmation dialog
# Parameters: $1 - target mode ("hd" or "crt")
# Returns: 0 if confirmed, 1 if cancelled
confirm_mode_switch() {
    local target_mode="$1"
    local target_display=$(get_mode_display_name "$target_mode")
    local current_mode=$(detect_current_mode)
    local current_display=$(get_mode_display_name "$current_mode")
    
    dialog --title "Confirm Mode Switch" \
           --backtitle "HD/CRT Mode Switcher" \
           --yes-label "PROCEED" \
           --no-label "CANCEL" \
           --yesno "Are you sure you want to switch from $current_display to $target_display?\n\nThis will modify system files and require a reboot." \
           10 50
    return $?
}

# Function: show_safety_disclaimer
# Purpose: Step 3 - Display mode-specific safety disclaimer
# Parameters: $1 - target mode ("hd" or "crt")
# Returns: 0 if user understands, 1 if cancelled
show_safety_disclaimer() {
    local target_mode="$1"
    
    if [ "$target_mode" = "crt" ]; then
        # HD → CRT Mode: Warning about turning on CRT after BIOS boot
        dialog --title "IMPORTANT SAFETY WARNING" \
               --backtitle "HD/CRT Mode Switcher" \
               --yes-label "PROCEED" \
               --no-label "CANCEL" \
               --yesno "Before proceeding, you MUST:\n\n1. DO NOT IMMEDIATELY TURN ON YOUR CRT\n2. Keep your CRT Monitor off until after BIOS boot\n\nWARNING:\nHigh frequencies during PC BIOS boot could DAMAGE your monitor!\n\nOnly turn on your monitor AFTER Batocera has fully booted." \
               16 65
    else
        # CRT → HD Mode: CRITICAL warning about turning OFF CRT immediately
        dialog --title "CRITICAL: CRT MONITOR SAFETY" \
               --backtitle "HD/CRT Mode Switcher" \
               --yes-label "I UNDERSTAND" \
               --no-label "CANCEL" \
               --yesno "Before proceeding, you MUST:\n\n1. TURN OFF YOUR CRT IMMEDIATELY BEFORE RESET\n2. Keep it OFF during the whole duration of HD Mode\n\nWARNING:\nHigh frequencies during PC BIOS boot and HD Mode could DAMAGE your monitor!\n\nOnly turn on your monitor AFTER CRT Mode has been initialized and AFTER Batocera has fully booted." \
               18 70
    fi
    return $?
}

# Function: show_progress
# Purpose: Show progress during backup/restore
# Parameters: $1 - message
show_progress() {
    local message="$1"
    dialog --title "Processing" \
           --backtitle "HD/CRT Mode Switcher" \
           --infobox "$message\n\nPlease wait..." \
           8 50
    sleep 1
}

# Function: show_success_message
# Purpose: Step 4 - Show mode-specific success message after mode switch
# Parameters: $1 - target mode ("hd" or "crt")
# Returns: 0
show_success_message() {
    local target_mode="$1"
    local target_display=$(get_mode_display_name "$target_mode")
    
    if [ "$target_mode" = "crt" ]; then
        # Switched to CRT Mode
        dialog --title "Mode Switch Complete" \
               --backtitle "HD/CRT Mode Switcher" \
               --msgbox "Successfully saved CRT Mode configs\n\nREMEMBER:\n- Keep monitor OFF during BIOS boot\n- Turn on your monitor AFTER CRT Mode has been initialized and AFTER Batocera has fully booted\n\nSystem will reboot now..." \
               14 65
    else
        # Switched to HD Mode
        dialog --title "Mode Switch Complete" \
               --backtitle "HD/CRT Mode Switcher" \
               --msgbox "Successfully saved HD Mode configs\n\nSystem will reboot now..." \
               10 50
    fi
    return $?
}

# Function: show_error_message
# Purpose: Show error message
# Parameters: $1 - error message
show_error_message() {
    local error_msg="$1"
    dialog --title "Error" \
           --backtitle "HD/CRT Mode Switcher" \
           --msgbox "An error occurred:\n\n$error_msg\n\nPlease check the logs for details." \
           12 60
}

