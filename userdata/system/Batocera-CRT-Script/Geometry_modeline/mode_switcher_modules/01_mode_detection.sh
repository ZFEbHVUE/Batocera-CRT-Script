#######################################################################################
# Module 02: Mode Detection
#######################################################################################

# Function: detect_current_mode
# Purpose: Determine if system is in HD or CRT mode
# Returns: "hd" or "crt"
detect_current_mode() {
    # REFACTORED: Userdata-only approach - removed /etc/switchres.ini check
    
    # Priority 1: Check videomodes.conf existence (CRT-only file)
    if [ -f "/userdata/system/videomodes.conf" ]; then
        echo "crt"
        return 0
    fi
    
    # Priority 2: Check batocera.conf for CRT settings
    if [ -f "/userdata/system/batocera.conf" ]; then
        if grep -q "crt_switch_resolution\|CRT CONFIG RETROARCH" /userdata/system/batocera.conf 2>/dev/null; then
            echo "crt"
            return 0
        fi
    fi
    
    # Default: HD Mode
    echo "hd"
}

# Function: get_mode_display_name
# Purpose: Get human-readable mode name
# Parameters: $1 - mode ("hd" or "crt")
# Returns: "HD Mode" or "CRT Mode"
get_mode_display_name() {
    case "$1" in
        "hd") echo "HD Mode" ;;
        "crt") echo "CRT Mode" ;;
        *) echo "Unknown Mode" ;;
    esac
}

# Function: check_crt_script_installed
# Purpose: Verify CRT Script has been installed
# Returns: 0 if installed, 1 if not
check_crt_script_installed() {
    if [ -f "$CRT_BACKUP_CHECK" ]; then
        return 0
    fi
    return 1
}

