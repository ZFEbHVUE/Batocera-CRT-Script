#######################################################################################
# Module 02b: HD Video Output Selection (First-Time Setup)
#######################################################################################

# Function: scan_xrandr_outputs
# Purpose: Scan available video outputs using DRM sysfs
# Returns: Populates ALL_OUTPUTS and CONNECTED_OUTPUTS arrays
# Note: Uses DRM sysfs instead of xrandr because CRT mode disables other outputs in X11
scan_xrandr_outputs() {
    ALL_OUTPUTS=()
    CONNECTED_OUTPUTS=()
    
    # Use DRM sysfs - shows ALL physical outputs regardless of X11 config
    for d in /sys/class/drm/card*-*; do
        [ -e "$d/status" ] || continue
        
        # Extract output name (e.g., card0-DP-1 -> DP-1)
        local name="${d##*/}"
        name="${name#card[0-9]-}"
        name="${name#card[0-9][0-9]-}"
        
        # Skip virtual/writeback connectors
        case "$name" in
            Writeback*|Virtual*|VIRTUAL*) continue ;;
        esac
        
        [ -z "$name" ] && continue
        
        # Check connection status
        local status=$(cat "$d/status" 2>/dev/null)
        
        ALL_OUTPUTS+=("$name")
        if [ "$status" = "connected" ]; then
            CONNECTED_OUTPUTS+=("$name")
        fi
    done
    
    [ ${#ALL_OUTPUTS[@]} -eq 0 ] && return 1
    return 0
}

# Function: get_current_crt_output
# Purpose: Get the current CRT output from batocera.conf
# Returns: Output name or empty string
get_current_crt_output() {
    if [ -f "/userdata/system/batocera.conf" ]; then
        grep '^global\.videooutput=' /userdata/system/batocera.conf 2>/dev/null | cut -d'=' -f2 | head -1
    fi
}

# Function: get_current_hd_output
# Purpose: Get the saved HD output from backup
# Returns: Output name or empty string
get_current_hd_output() {
    local hd_video_file="${MODE_BACKUP_DIR}/hd_mode/video_settings/video_output.txt"
    if [ -f "$hd_video_file" ]; then
        grep '^global\.videooutput=' "$hd_video_file" 2>/dev/null | cut -d'=' -f2 | head -1
    fi
}

# Function: show_output_selection_dialog
# Purpose: Unified dialog for selecting video output (HD or CRT)
# Parameters: $1 - mode ("hd" or "crt"), $2 - current_other_output, $3 - current_selection, $4 - other_is_saved ("true"/"false")
# Returns: Selected output in SELECTED_OUTPUT variable, 0 on success, 1 on cancel
show_output_selection_dialog() {
    local select_mode="$1"
    local other_output="$2"
    local selected_output="$3"
    local other_is_saved="${4:-false}"
    
    local title=""
    local prompt=""
    local other_marker=""
    local select_marker=""
    
    if [ "$select_mode" = "hd" ]; then
        title="HD Mode Video Output Setup"
        prompt="Select an output for HD Mode:\n(Use UP/DOWN to navigate, B to select)\n\nDETECTED OUTPUT   CONNECTED PORT   CURRENT OUTPUT"
        # Use CURRENT only if loaded from saved config, otherwise SELECTED
        if [ "$other_is_saved" = "true" ]; then
            other_marker="[CURRENT CRT]"
        else
            other_marker="[SELECTED FOR CRT]"
        fi
        select_marker="[SELECTED FOR HD]"
    else
        title="CRT Mode Video Output Setup"
        prompt="Select an output for CRT Mode:\n(Use UP/DOWN to navigate, B to select)\n\nDETECTED OUTPUT   CONNECTED PORT   CURRENT OUTPUT"
        # Use CURRENT only if loaded from saved config, otherwise SELECTED
        if [ "$other_is_saved" = "true" ]; then
            other_marker="[CURRENT HD]"
        else
            other_marker="[SELECTED FOR HD]"
        fi
        select_marker="[SELECTED FOR CRT]"
    fi
    
    echo "[$(date +"%H:%M:%S")]: $select_mode output selection started" >> "$LOG_FILE"
    
    local default_item=""
    
    while true; do
        # Scan outputs
        if ! scan_xrandr_outputs; then
            dialog --title "Error" \
                   --backtitle "HD/CRT Mode Switcher" \
                   --msgbox "Could not detect video outputs.\n\nPlease check your system." \
                   10 50
            return 1
        fi
        
        if [ ${#ALL_OUTPUTS[@]} -eq 0 ]; then
            dialog --title "Error" \
                   --backtitle "HD/CRT Mode Switcher" \
                   --msgbox "No video outputs detected.\n\nPlease check your display connections." \
                   10 50
            return 1
        fi
        
        # Build menu items with 3-column layout
        local menu_items=()
        for output in "${ALL_OUTPUTS[@]}"; do
            local conn_status="disconnected"
            local current_status="[DISABLED]"
            
            # Check if connected
            for conn in "${CONNECTED_OUTPUTS[@]}"; do
                if [ "$output" = "$conn" ]; then
                    conn_status="connected"
                    break
                fi
            done
            
            # Determine CURRENT OUTPUT column value
            if [ "$output" = "$selected_output" ]; then
                current_status="$select_marker"
            elif [ "$output" = "$other_output" ]; then
                current_status="$other_marker"
            fi
            
            # Format columns with fixed widths for alignment
            # CONNECTED PORT (14 chars) | CURRENT OUTPUT
            local conn_col=$(printf "%-14s" "$conn_status")
            menu_items+=("$output" "$conn_col $current_status")
        done
        
        # Add separator and action items
        menu_items+=("--------" "─────────────────────────────────")
        menu_items+=("CONFIRM" "Proceed with selected")
        menu_items+=("RESCAN" "Rescan outputs")
        menu_items+=("CANCEL" "Go back")
        
        # Determine default highlight
        if [ -z "$default_item" ]; then
            if [ -n "$selected_output" ]; then
                default_item="CONFIRM"
            else
                default_item="${ALL_OUTPUTS[0]}"
            fi
        fi
        
        # Show selection dialog
        local choice
        choice=$(dialog --title "$title" \
                       --backtitle "HD/CRT Mode Switcher" \
                       --default-item "$default_item" \
                       --no-cancel \
                       --no-ok \
                       --menu "$prompt" \
                       22 70 $((${#ALL_OUTPUTS[@]} + 5)) \
                       "${menu_items[@]}" \
                       3>&1 1>&2 2>&3)
        
        local exit_code=$?
        
        if [ $exit_code -ne 0 ]; then
            return 1
        fi
        
        # Handle separator
        if [ "$choice" = "--------" ]; then
            default_item="CONFIRM"
            continue
        fi
        
        # Handle CANCEL
        if [ "$choice" = "CANCEL" ]; then
            return 1
        fi
        
        # Handle RESCAN
        if [ "$choice" = "RESCAN" ]; then
            dialog --title "Rescanning" \
                   --backtitle "HD/CRT Mode Switcher" \
                   --infobox "Rescanning outputs..." \
                   5 40
            sleep 1
            default_item="RESCAN"
            continue
        fi
        
        # Handle CONFIRM
        if [ "$choice" = "CONFIRM" ]; then
            if [ -z "$selected_output" ]; then
                dialog --title "No Output Selected" \
                       --backtitle "HD/CRT Mode Switcher" \
                       --msgbox "You must select an output first.\n\nUse UP/DOWN to highlight an output, then press B to select it." \
                       10 55
                default_item="${ALL_OUTPUTS[0]}"
                continue
            fi
            
            SELECTED_OUTPUT="$selected_output"
            echo "[$(date +"%H:%M:%S")]: $select_mode output confirmed: $selected_output" >> "$LOG_FILE"
            return 0
        fi
        
        # User selected an output
        local new_selection="$choice"
        
        # Warn if selecting same as other mode
        if [ "$new_selection" = "$other_output" ] && [ -n "$other_output" ]; then
            local warn_mode=""
            if [ "$select_mode" = "hd" ]; then
                warn_mode="CRT"
            else
                warn_mode="HD"
            fi
            
            dialog --title "Warning: Same as $warn_mode Output" \
                   --backtitle "HD/CRT Mode Switcher" \
                   --yes-label "SELECT ANYWAY" \
                   --no-label "GO BACK" \
                   --yesno "WARNING: You selected the same output used for $warn_mode Mode!\n\n  $new_selection\n\nThis is typically NOT what you want.\n\nAre you sure?" \
                   12 60
            
            if [ $? -ne 0 ]; then
                default_item="$new_selection"
                continue
            fi
        fi
        
        # Store selection
        selected_output="$new_selection"
        default_item="CONFIRM"
        echo "[$(date +"%H:%M:%S")]: User selected $select_mode output: $selected_output" >> "$LOG_FILE"
    done
}

# Function: show_boot_resolution_dialog
# Purpose: Dialog for selecting CRT boot resolution
# Parameters: $1 - current_selection
# Returns: Selected boot mode in SELECTED_BOOT variable, 0 on success, 1 on cancel
show_boot_resolution_dialog() {
    local selected_boot="$1"
    
    echo "[$(date +"%H:%M:%S")]: Boot resolution selection started" >> "$LOG_FILE"
    
    # Get available boot modes
    if ! get_available_boot_modes; then
        dialog --title "Error" \
               --backtitle "HD/CRT Mode Switcher" \
               --msgbox "No Boot_ modes found in videomodes.conf.\n\nCRT Script may not be properly installed." \
               10 55
        return 1
    fi
    
    local default_item=""
    
    while true; do
        # Build menu items
        local menu_items=()
        for mode in "${BOOT_MODES[@]}"; do
            local marker=""
            
            if [ "$mode" = "$selected_boot" ]; then
                marker="  [SELECTED]"
            fi
            
            menu_items+=("$mode" "$marker")
        done
        
        # Add separator and action items
        menu_items+=("--------" "─────────────────────────────")
        menu_items+=("CONFIRM" "Proceed with selected")
        menu_items+=("CANCEL" "Go back")
        
        # Determine default highlight
        if [ -z "$default_item" ]; then
            if [ -n "$selected_boot" ]; then
                default_item="CONFIRM"
            else
                default_item="${BOOT_MODES[0]}"
            fi
        fi
        
        # Show selection dialog
        local choice
        choice=$(dialog --title "CRT Boot Resolution Setup" \
                       --backtitle "HD/CRT Mode Switcher" \
                       --default-item "$default_item" \
                       --no-cancel \
                       --no-ok \
                       --menu "Select boot resolution for CRT Mode:\n(Use UP/DOWN to navigate, B to select)" \
                       18 70 $((${#BOOT_MODES[@]} + 4)) \
                       "${menu_items[@]}" \
                       3>&1 1>&2 2>&3)
        
        local exit_code=$?
        
        if [ $exit_code -ne 0 ]; then
            return 1
        fi
        
        # Handle separator
        if [ "$choice" = "--------" ]; then
            default_item="CONFIRM"
            continue
        fi
        
        # Handle CANCEL
        if [ "$choice" = "CANCEL" ]; then
            return 1
        fi
        
        # Handle CONFIRM
        if [ "$choice" = "CONFIRM" ]; then
            if [ -z "$selected_boot" ]; then
                dialog --title "No Resolution Selected" \
                       --backtitle "HD/CRT Mode Switcher" \
                       --msgbox "You must select a boot resolution first.\n\nUse UP/DOWN to highlight a resolution, then press B to select it." \
                       10 55
                default_item="${BOOT_MODES[0]}"
                continue
            fi
            
            SELECTED_BOOT="$selected_boot"
            echo "[$(date +"%H:%M:%S")]: Boot resolution confirmed: $selected_boot" >> "$LOG_FILE"
            return 0
        fi
        
        # User selected a boot mode
        selected_boot="$choice"
        default_item="CONFIRM"
        echo "[$(date +"%H:%M:%S")]: User selected boot resolution: $selected_boot" >> "$LOG_FILE"
    done
}

# Function: show_config_summary_dialog
# Purpose: Show summary of all configs with EDIT option
# Parameters: $1 - target_mode, $2 - hd_output, $3 - crt_output, $4 - crt_boot
# Returns: Action in SUMMARY_ACTION variable ("confirm", "edit_hd", "edit_crt", "edit_boot", "cancel")
show_config_summary_dialog() {
    local target_mode="$1"
    local hd_output="$2"
    local crt_output="$3"
    local crt_boot="$4"
    
    local menu_items=()
    
    # Build summary display
    local hd_display="HD Output:   $hd_output"
    local crt_display="CRT Output:  $crt_output"
    local boot_display="CRT Boot:    $crt_boot"
    
    # Add markers for current mode
    if [ "$target_mode" = "hd" ]; then
        hd_display="$hd_display  << SWITCHING TO"
    else
        crt_display="$crt_display  << SWITCHING TO"
    fi
    
    menu_items+=("CONFIRM" ">>> Switch to $(get_mode_display_name "$target_mode")")
    
    # Add all EDIT options
    menu_items+=("EDIT_HD" "Edit HD Output ($hd_output)")
    menu_items+=("EDIT_CRT" "Edit CRT Output ($crt_output)")
    menu_items+=("EDIT_BOOT" "Edit CRT Boot Resolution")
    
    menu_items+=("--------" "─────────────────────────────")
    menu_items+=("CANCEL" "Return to EmulationStation")
    
    local choice
    choice=$(dialog --title "Mode Switch Configuration" \
                   --backtitle "HD/CRT Mode Switcher" \
                   --default-item "CONFIRM" \
                   --no-cancel \
                   --no-ok \
                   --menu "Current Configuration:\n\n$hd_display\n$crt_display\n$boot_display\n\nSelect action:" \
                   20 70 6 \
                   "${menu_items[@]}" \
                   3>&1 1>&2 2>&3)
    
    local exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        SUMMARY_ACTION="cancel"
        return 1
    fi
    
    case "$choice" in
        "CONFIRM") SUMMARY_ACTION="confirm" ;;
        "EDIT_HD") SUMMARY_ACTION="edit_hd" ;;
        "EDIT_CRT") SUMMARY_ACTION="edit_crt" ;;
        "EDIT_BOOT") SUMMARY_ACTION="edit_boot" ;;
        "CANCEL"|"--------") SUMMARY_ACTION="cancel"; return 1 ;;
        *) SUMMARY_ACTION="cancel"; return 1 ;;
    esac
    
    return 0
}

# Function: get_current_crt_backup_output
# Purpose: Get the saved CRT output from backup
# Returns: Output name or empty string
get_current_crt_backup_output() {
    local crt_video_file="${MODE_BACKUP_DIR}/crt_mode/video_settings/video_output.txt"
    if [ -f "$crt_video_file" ]; then
        grep '^global\.videooutput=' "$crt_video_file" 2>/dev/null | cut -d'=' -f2 | head -1
    fi
}

# Function: get_crt_boot_resolution
# Purpose: Get the current CRT boot resolution from batocera.conf or backup
# Returns: Boot resolution DISPLAY NAME (e.g., "Boot_480i 1.0:0:0 15KHz 60Hz") or empty
# Note: Handles both mode IDs (769x576.50.00060) and display names (Boot_576i...)
get_crt_boot_resolution() {
    local boot_mode=""
    
    # Ensure BOOT_MODES arrays are populated for ID-to-name conversion
    get_available_boot_modes 2>/dev/null || true
    
    # First try current batocera.conf (if in CRT mode)
    if [ -f "/userdata/system/batocera.conf" ]; then
        boot_mode=$(grep '^global\.videomode=' /userdata/system/batocera.conf 2>/dev/null | cut -d'=' -f2 | head -1)
        if [ -n "$boot_mode" ]; then
            # Check if it's a display name (starts with Boot_)
            if [[ "$boot_mode" == Boot_* ]]; then
                echo "$boot_mode"
                return 0
            fi
            # Check if it's a mode ID - try to convert to display name
            local display_name=$(get_boot_display_name "$boot_mode")
            if [ -n "$display_name" ]; then
                echo "$display_name"
                return 0
            fi
        fi
    fi
    
    # Try CRT mode backup
    local backup_file="${MODE_BACKUP_DIR}/crt_mode/video_settings/video_mode.txt"
    if [ -f "$backup_file" ]; then
        boot_mode=$(grep '^global\.videomode=' "$backup_file" 2>/dev/null | cut -d'=' -f2 | head -1)
        if [ -n "$boot_mode" ]; then
            # Check if it's a display name (starts with Boot_)
            if [[ "$boot_mode" == Boot_* ]]; then
                echo "$boot_mode"
                return 0
            fi
            # Check if it's a mode ID - try to convert to display name
            local display_name=$(get_boot_display_name "$boot_mode")
            if [ -n "$display_name" ]; then
                echo "$display_name"
                return 0
            fi
        fi
    fi
    
    echo ""
}

# Function: get_available_boot_modes
# Purpose: Get list of available Boot_ modes from videomodes.conf
# Returns: Populates BOOT_MODES (display names) and BOOT_MODE_IDS (mode identifiers) arrays
# Note: Checks current system first, then CRT backup (for HD Mode)
get_available_boot_modes() {
    BOOT_MODES=()
    BOOT_MODE_IDS=()
    
    # Determine which videomodes.conf to use
    local videomodes_file=""
    if [ -f "/userdata/system/videomodes.conf" ]; then
        videomodes_file="/userdata/system/videomodes.conf"
    elif [ -f "${MODE_BACKUP_DIR}/crt_mode/userdata_configs/videomodes.conf" ]; then
        # HD Mode - use CRT backup
        videomodes_file="${MODE_BACKUP_DIR}/crt_mode/userdata_configs/videomodes.conf"
    fi
    
    if [ -n "$videomodes_file" ] && [ -f "$videomodes_file" ]; then
        while IFS= read -r line; do
            # Skip empty lines and comment lines (hardened for user-edited files)
            [ -z "${line// }" ] && continue  # Empty or whitespace-only
            [[ "$line" =~ ^[[:space:]]*# ]] && continue  # Comment line
            
            # Format: 769x576.50.00060:Boot_576i 1.0:0:0 15KHz 50Hz
            # Extract mode ID (before colon) and display name (after colon)
            local mode_id="${line%%:*}"
            local display_name="${line#*:}"
            
            # Validate mode_id has reasonable length (at least 4 chars for substr safety in other scripts)
            if [ -n "$display_name" ] && [ -n "$mode_id" ] && [ ${#mode_id} -gt 3 ]; then
                BOOT_MODES+=("$display_name")
                BOOT_MODE_IDS+=("$mode_id")
            fi
        done < <(grep 'Boot_' "$videomodes_file" 2>/dev/null)
    fi
    
    [ ${#BOOT_MODES[@]} -eq 0 ] && return 1
    return 0
}

# Function: get_boot_mode_id
# Purpose: Get mode ID from display name
# Parameters: $1 - display name
# Returns: mode ID or empty string
get_boot_mode_id() {
    local display_name="$1"
    for i in "${!BOOT_MODES[@]}"; do
        if [ "${BOOT_MODES[$i]}" = "$display_name" ]; then
            echo "${BOOT_MODE_IDS[$i]}"
            return 0
        fi
    done
    echo ""
    return 1
}

# Function: get_boot_display_name
# Purpose: Get display name from mode ID
# Parameters: $1 - mode ID
# Returns: display name or empty string
get_boot_display_name() {
    local mode_id="$1"
    for i in "${!BOOT_MODE_IDS[@]}"; do
        if [ "${BOOT_MODE_IDS[$i]}" = "$mode_id" ]; then
            echo "${BOOT_MODES[$i]}"
            return 0
        fi
    done
    echo ""
    return 1
}

# Function: check_mandatory_configs
# Purpose: Check if all mandatory configs are set
# Parameters: $1 - target_mode ("hd" or "crt")
# Sets global variables: NEEDS_HD_CONFIG, NEEDS_CRT_CONFIG, NEEDS_BOOT_CONFIG, ALL_CONFIGURED
check_mandatory_configs() {
    local target_mode="$1"
    
    # Get current values
    local hd_output=$(get_current_hd_output)
    local crt_output=$(get_current_crt_backup_output)
    if [ -z "$crt_output" ]; then
        crt_output=$(get_current_crt_output)
    fi
    local crt_boot=$(get_crt_boot_resolution)
    
    # Determine what's missing
    NEEDS_HD_CONFIG=false
    NEEDS_CRT_CONFIG=false
    NEEDS_BOOT_CONFIG=false
    
    [ -z "$hd_output" ] && NEEDS_HD_CONFIG=true
    [ -z "$crt_output" ] && NEEDS_CRT_CONFIG=true
    [ -z "$crt_boot" ] && NEEDS_BOOT_CONFIG=true
    
    # Check if all configured
    if [ "$NEEDS_HD_CONFIG" = false ] && [ "$NEEDS_CRT_CONFIG" = false ] && [ "$NEEDS_BOOT_CONFIG" = false ]; then
        ALL_CONFIGURED=true
    else
        ALL_CONFIGURED=false
    fi
    
    # Store values for later use
    CURRENT_HD_OUTPUT="$hd_output"
    CURRENT_CRT_OUTPUT="$crt_output"
    CURRENT_CRT_BOOT="$crt_boot"
}

# Function: run_mode_switch_ui
# Purpose: Main UI flow for mode switching - checks configs and shows appropriate dialogs
# Parameters: $1 - target_mode ("hd" or "crt")
# Returns: 0 on success (all configs saved), 1 on cancel
# Sets: USER_HD_OUTPUT, USER_CRT_OUTPUT, USER_CRT_BOOT with final values
run_mode_switch_ui() {
    local target_mode="$1"
    
    echo "[$(date +"%H:%M:%S")]: Mode switch UI started for target: $target_mode" >> "$LOG_FILE"
    
    # Check what's already configured
    check_mandatory_configs "$target_mode"
    
    echo "[$(date +"%H:%M:%S")]: Config check - HD: $CURRENT_HD_OUTPUT, CRT: $CURRENT_CRT_OUTPUT, Boot: $CURRENT_CRT_BOOT" >> "$LOG_FILE"
    echo "[$(date +"%H:%M:%S")]: Needs - HD: $NEEDS_HD_CONFIG, CRT: $NEEDS_CRT_CONFIG, Boot: $NEEDS_BOOT_CONFIG, All configured: $ALL_CONFIGURED" >> "$LOG_FILE"
    
    # Working variables for user selections
    local working_hd="$CURRENT_HD_OUTPUT"
    local working_crt="$CURRENT_CRT_OUTPUT"
    local working_boot="$CURRENT_CRT_BOOT"
    
    # Track whether values are from saved config (true) or just selected (false)
    local hd_is_saved="false"
    local crt_is_saved="false"
    [ -n "$CURRENT_HD_OUTPUT" ] && hd_is_saved="true"
    [ -n "$CURRENT_CRT_OUTPUT" ] && crt_is_saved="true"
    
    # Main UI loop
    while true; do
        
        # If all configured, show summary with EDIT option
        if [ "$NEEDS_HD_CONFIG" = false ] && [ "$NEEDS_CRT_CONFIG" = false ] && [ "$NEEDS_BOOT_CONFIG" = false ]; then
            
            # Final safety check - ensure all values are actually set
            if [ -z "$working_hd" ] || [ -z "$working_crt" ] || [ -z "$working_boot" ]; then
                dialog --title "Configuration Incomplete" \
                       --backtitle "HD/CRT Mode Switcher" \
                       --msgbox "ERROR: One or more configurations are missing.\n\nHD Output: ${working_hd:-NOT SET}\nCRT Output: ${working_crt:-NOT SET}\nCRT Boot: ${working_boot:-NOT SET}\n\nPlease complete all selections." \
                       14 55
                
                # Reset flags for missing values
                [ -z "$working_hd" ] && NEEDS_HD_CONFIG=true
                [ -z "$working_crt" ] && NEEDS_CRT_CONFIG=true
                [ -z "$working_boot" ] && NEEDS_BOOT_CONFIG=true
                continue
            fi
            
            show_config_summary_dialog "$target_mode" "$working_hd" "$working_crt" "$working_boot"
            
            case "$SUMMARY_ACTION" in
                "confirm")
                    # Save and proceed
                    break
                    ;;
                "edit_hd")
                    show_output_selection_dialog "hd" "$working_crt" "$working_hd" "$crt_is_saved"
                    if [ $? -eq 0 ]; then
                        working_hd="$SELECTED_OUTPUT"
                        hd_is_saved="false"
                    fi
                    continue
                    ;;
                "edit_crt")
                    show_output_selection_dialog "crt" "$working_hd" "$working_crt" "$hd_is_saved"
                    if [ $? -eq 0 ]; then
                        working_crt="$SELECTED_OUTPUT"
                        crt_is_saved="false"
                    fi
                    continue
                    ;;
                "edit_boot")
                    show_boot_resolution_dialog "$working_boot"
                    if [ $? -eq 0 ]; then
                        working_boot="$SELECTED_BOOT"
                    fi
                    continue
                    ;;
                "cancel"|*)
                    return 1
                    ;;
            esac
        fi
        
        # Handle missing configs based on target mode
        if [ "$target_mode" = "hd" ]; then
            # Switching TO HD Mode
            
            # FIRST: Must have CRT output configured (you're currently in CRT mode!)
            if [ "$NEEDS_CRT_CONFIG" = true ]; then
                dialog --title "CRT Output Not Configured" \
                       --backtitle "HD/CRT Mode Switcher" \
                       --msgbox "You have not configured CRT Mode Output yet.\n\nPlease select an output for CRT Mode first." \
                       10 55
                
                show_output_selection_dialog "crt" "$working_hd" "$working_crt" "$hd_is_saved"
                if [ $? -ne 0 ]; then
                    return 1
                fi
                working_crt="$SELECTED_OUTPUT"
                crt_is_saved="false"
                NEEDS_CRT_CONFIG=false
            fi
            
            # SECOND: Must have CRT boot resolution
            if [ "$NEEDS_BOOT_CONFIG" = true ]; then
                show_boot_resolution_dialog "$working_boot"
                if [ $? -ne 0 ]; then
                    return 1
                fi
                working_boot="$SELECTED_BOOT"
                NEEDS_BOOT_CONFIG=false
            fi
            
            # THIRD: Must have HD output (where you're switching TO)
            if [ "$NEEDS_HD_CONFIG" = true ]; then
                show_output_selection_dialog "hd" "$working_crt" "$working_hd" "$crt_is_saved"
                if [ $? -ne 0 ]; then
                    return 1
                fi
                working_hd="$SELECTED_OUTPUT"
                hd_is_saved="false"
                NEEDS_HD_CONFIG=false
            fi
            
        else
            # Switching TO CRT Mode
            
            # Must have CRT output
            if [ "$NEEDS_CRT_CONFIG" = true ]; then
                show_output_selection_dialog "crt" "$working_hd" "$working_crt" "$hd_is_saved"
                if [ $? -ne 0 ]; then
                    return 1
                fi
                working_crt="$SELECTED_OUTPUT"
                crt_is_saved="false"
                NEEDS_CRT_CONFIG=false
            fi
            
            # Must have CRT boot resolution
            if [ "$NEEDS_BOOT_CONFIG" = true ]; then
                show_boot_resolution_dialog "$working_boot"
                if [ $? -ne 0 ]; then
                    return 1
                fi
                working_boot="$SELECTED_BOOT"
                NEEDS_BOOT_CONFIG=false
            fi
            
            # Must have HD output (for when switching back)
            if [ "$NEEDS_HD_CONFIG" = true ]; then
                show_output_selection_dialog "hd" "$working_crt" "$working_hd" "$crt_is_saved"
                if [ $? -ne 0 ]; then
                    return 1
                fi
                working_hd="$SELECTED_OUTPUT"
                hd_is_saved="false"
                NEEDS_HD_CONFIG=false
            fi
        fi
        
        # After filling in missing configs, loop back to show summary
    done
    
    # Save all selections to backup files
    echo "[$(date +"%H:%M:%S")]: Saving selections - HD: $working_hd, CRT: $working_crt, Boot: $working_boot" >> "$LOG_FILE"
    
    # Save HD output
    mkdir -p "${MODE_BACKUP_DIR}/hd_mode/video_settings"
    echo "global.videooutput=$working_hd" > "${MODE_BACKUP_DIR}/hd_mode/video_settings/video_output.txt"
    
    # Save CRT output
    mkdir -p "${MODE_BACKUP_DIR}/crt_mode/video_settings"
    echo "global.videooutput=$working_crt" > "${MODE_BACKUP_DIR}/crt_mode/video_settings/video_output.txt"
    
    # Save CRT boot resolution - convert display name to mode ID for batocera.conf
    # working_boot contains display name like "Boot_576i 1.0:0:0 15KHz 50Hz"
    # We need mode ID like "769x576.50.00060" for batocera.conf
    
    # Ensure BOOT_MODES arrays are populated for lookup
    get_available_boot_modes 2>/dev/null || true
    
    local boot_mode_id=$(get_boot_mode_id "$working_boot")
    echo "[$(date +"%H:%M:%S")]: Converting boot mode - input: '$working_boot', output: '$boot_mode_id'" >> "$LOG_FILE"
    
    if [ -n "$boot_mode_id" ]; then
        echo "global.videomode=$boot_mode_id" > "${MODE_BACKUP_DIR}/crt_mode/video_settings/video_mode.txt"
        echo "[$(date +"%H:%M:%S")]: Saved boot mode ID: $boot_mode_id (display: $working_boot)" >> "$LOG_FILE"
    else
        # Fallback - if working_boot is already a mode ID, use it directly
        echo "global.videomode=$working_boot" > "${MODE_BACKUP_DIR}/crt_mode/video_settings/video_mode.txt"
        echo "[$(date +"%H:%M:%S")]: WARNING: Could not convert '$working_boot' to mode ID, saved as-is" >> "$LOG_FILE"
    fi
    
    # Set output variables for caller
    USER_HD_OUTPUT="$working_hd"
    USER_CRT_OUTPUT="$working_crt"
    USER_CRT_BOOT="$working_boot"
    
    echo "[$(date +"%H:%M:%S")]: Mode switch UI completed successfully" >> "$LOG_FILE"
    return 0
}

