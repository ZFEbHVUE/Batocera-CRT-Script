#######################################################################################
# Module 02b: HD Video Output Selection (First-Time Setup)
#######################################################################################

# Function: drm_name_to_xrandr
# Purpose: Convert DRM sysfs connector name to xrandr-compatible name
# Parameters: $1 - DRM connector name (e.g., HDMI-A-2, DP-1)
# Returns: xrandr name via echo (e.g., HDMI-2, DP-1)
# Note: The kernel defines HDMI-A and HDMI-B as distinct DRM connector types
#        (drm_connector_enum_list in drm_connector.c). xrandr normalizes both
#        to HDMI-N. HDMI-A is common on AMD/Intel; HDMI-B (dual-link) is defined
#        but rarely seen in practice. Other types (DP, DVI-*, VGA, eDP, LVDS)
#        match between DRM sysfs and xrandr.
drm_name_to_xrandr() {
    local name="$1"
    case "$name" in
        HDMI-[A-Z]-*) echo "HDMI-${name#HDMI-?-}" ;;
        *)            echo "$name" ;;
    esac
}

# Function: scan_xrandr_outputs
# Purpose: Scan available video outputs using DRM sysfs, normalized to xrandr names
# Returns: Populates ALL_OUTPUTS and CONNECTED_OUTPUTS arrays with xrandr-format names
# Note: Uses DRM sysfs instead of xrandr because CRT mode disables other outputs in X11.
#        Names are normalized via drm_name_to_xrandr() so that values written to
#        batocera.conf match what batocera-resolution listOutputs / ES expect.
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
        
        # Normalize DRM name to xrandr format (e.g., HDMI-A-2 -> HDMI-2)
        name=$(drm_name_to_xrandr "$name")
        
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

# A saved HD mode the switcher can restore. default/auto is what falls through to 640x480.
_hd_resolution_usable() {
    local value="$1"
    [ -z "$value" ] && return 1
    case "$value" in
        default|auto|Auto|DEFAULT|max-640x480) return 1 ;;
    esac
    return 0
}

# HD stack for the mode we switch back to. Live check only counts while HD is running.
# Dual-boot (/boot/crt) means the stock boot, which is HD, is Wayland.
detect_hd_display_stack() {
    local current mode
    current=$(detect_current_mode 2>/dev/null)
    if [ "$current" = "hd" ] && command -v batocera-resolution >/dev/null 2>&1; then
        mode=$(batocera-resolution getDisplayMode 2>/dev/null)
        case "$mode" in
            wayland) echo "wayland" ;;
            *) echo "xorg" ;;
        esac
        return 0
    fi
    if [ -f /boot/crt/linux ] && [ -f /boot/crt/batocera ]; then
        echo "wayland"
    else
        echo "xorg"
    fi
}

# LCD Steam Deck is Jupiter. OLED is Galileo. batocera.board is only the CPU tier.
_hd_is_steam_deck() {
    local model
    model=$(batocera-model 2>/dev/null)
    case "$model" in
        Jupiter|Galileo) return 0 ;;
    esac
    return 1
}

# Largest real mode on the saved or live list. Skips max-* caps.
_hd_panel_native_mode() {
    local id res w h px best best_px
    best=""
    best_px=0
    for id in "${HD_MODE_IDS[@]}"; do
        case "$id" in
            max-*|"") continue ;;
        esac
        res="${id%%.*}"
        w="${res%%x*}"
        h="${res#*x}"
        case "$w" in *[!0-9]*) continue ;; esac
        case "$h" in *[!0-9]*) continue ;; esac
        px=$((w * h))
        if [ "$px" -gt "$best_px" ]; then
            best="$id"
            best_px=$px
        fi
    done
    [ -n "$best" ] && printf '%s\n' "$best"
}

# Show 3440x1440.164999 as 3440x1440@165Hz. The stored id stays exact.
_hd_hz_pretty() {
    awk -v hz="$1" 'BEGIN {
        nearest = int(hz + 0.5)
        diff = hz - nearest
        if (diff < 0) diff = -diff
        if (diff < 0.05) printf "%d", nearest
        else printf "%.2f", hz
    }'
}

_hd_menu_label() {
    local id="$1"
    local res milli hz rate
    case "$id" in
        max-*) echo "maximum ${id#max-}" ; return ;;
        "") echo "NOT SET" ; return ;;
    esac
    # Wayland listModes: WIDTHxHEIGHT.<refresh millihertz>
    if echo "$id" | grep -qE '^[0-9]+x[0-9]+\.[0-9]+$'; then
        res="${id%%.*}"
        milli="${id#*.}"
        hz=$(awk -v m="$milli" 'BEGIN { printf "%.6f", m / 1000 }')
        echo "${res}@$(_hd_hz_pretty "$hz")Hz"
        return
    fi
    # X11 listModes: WIDTHxHEIGHT.REFRESH.FRACTION
    if echo "$id" | grep -qE '^[0-9]+x[0-9]+\.[0-9]+\.[0-9]+$'; then
        res=$(echo "$id" | cut -d. -f1)
        rate=$(echo "$id" | cut -d. -f2)
        echo "${res}@${rate}Hz"
        return
    fi
    echo "$id"
}

_hd_res_label() {
    _hd_menu_label "$1"
}

# listModes with no --screen follows the primary output. On a Steam Deck the CRT
# DAC becomes primary while it is plugged in, and that port only advertises
# 640x480. Pick the connected output whose real modes go above 640x480.
_hd_list_screen() {
    local outputs out line id res w h px top best best_px
    command -v batocera-resolution >/dev/null 2>&1 || return 0
    outputs=$(batocera-resolution listOutputs 2>/dev/null) || return 0
    best=""
    best_px=0
    while IFS= read -r out; do
        [ -z "$out" ] && continue
        top=0
        while IFS= read -r line; do
            id="${line%%:*}"
            case "$id" in max-*|"") continue ;; esac
            res="${id%%.*}"
            w="${res%%x*}"
            h="${res#*x}"
            case "$w" in *[!0-9]*) continue ;; esac
            case "$h" in *[!0-9]*) continue ;; esac
            px=$((w * h))
            [ "$px" -gt "$top" ] && top=$px
        done <<EOF
$(batocera-resolution --screen "$out" listModes 2>/dev/null)
EOF
        if [ "$top" -gt "$best_px" ]; then
            best_px=$top
            best=$out
        fi
    done <<EOF
$outputs
EOF
    [ -n "$best" ] && printf '%s\n' "$best"
}

_hd_screen_model() {
    local screen="$1" model=""
    if [ -n "$screen" ] && command -v wlr-randr >/dev/null 2>&1; then
        model=$(XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run}" WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}" wlr-randr 2>/dev/null \
            | awk -v screen="$screen" '
                $1 == screen { grab=1; next }
                grab && $0 !~ /^[[:space:]]/ { exit }
                grab && index($0, "Model:") { sub(/.*Model: /, ""); print; exit }
            ')
    fi
    if [ -z "$model" ] && [ -n "$screen" ] && command -v batocera-resolution >/dev/null 2>&1; then
        model=$(batocera-resolution --screen "$screen" outputModel 2>/dev/null | head -1)
    fi
    printf '%s\n' "$model"
}

# Name of the HD monitor whose mode list is saved. Written only while HD is running.
_hd_saved_monitor_name() {
    local f="${MODE_BACKUP_DIR}/hd_mode/video_settings/hd_monitor.txt"
    [ -f "$f" ] || return 0
    head -1 "$f" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

_hd_record_connected_monitor() {
    local model="" edid d name
    if [ -z "${WAYLAND_DISPLAY:-}" ]; then
        if [ -S /run/wayland-0 ] || ls /run/user/*/wayland-0 >/dev/null 2>&1; then
            export WAYLAND_DISPLAY=wayland-0
            export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run}"
        fi
    fi
    local screen
    screen=$(_hd_list_screen)
    if [ -n "$screen" ]; then
        model=$(_hd_screen_model "$screen")
    fi
    if [ -z "$model" ] && command -v wlr-randr >/dev/null 2>&1; then
        model=$(XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run}" WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}" wlr-randr 2>/dev/null \
            | awk -F'Model: ' '/Model:/ { print $2; exit }')
    fi
    if [ -z "$model" ] && command -v edid-decode >/dev/null 2>&1; then
        for d in /sys/class/drm/card*-*; do
            [ -f "$d/status" ] || continue
            [ "$(cat "$d/status" 2>/dev/null)" = "connected" ] || continue
            [ -r "$d/edid" ] || continue
            name="${d##*/}"
            name="${name#card*-}"
            case "$name" in Writeback*|Virtual*|VIRTUAL*) continue ;; esac
            model=$(edid-decode "$d/edid" 2>/dev/null | sed -n "s/.*Display Product Name: '\\([^']*\\)'.*/\\1/p" | head -1)
            [ -n "$model" ] && break
        done
    fi
    if [ -n "$model" ]; then
        mkdir -p "${MODE_BACKUP_DIR}/hd_mode/video_settings"
        printf '%s\n' "$model" > "${MODE_BACKUP_DIR}/hd_mode/video_settings/hd_monitor.txt"
    fi
}

# Saved value that restore will write. default does not count.
get_saved_hd_resolution() {
    local backup_file="${MODE_BACKUP_DIR}/hd_mode/video_settings/video_mode.txt"
    local value=""
    if [ -f "$backup_file" ]; then
        value=$(grep '^global\.videomode=' "$backup_file" 2>/dev/null | cut -d'=' -f2- | head -1)
        value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    fi
    if _hd_resolution_usable "$value"; then
        echo "$value"
    fi
}

# Populates HD_MODE_IDS, HD_MODE_LABELS, HD_MODES_SOURCE (live|saved|preset).
get_available_hd_modes() {
    HD_MODE_IDS=()
    HD_MODE_LABELS=()
    HD_MODES_SOURCE="preset"
    local stack current list_file line mode_id label
    stack=$(detect_hd_display_stack)
    current=$(detect_current_mode 2>/dev/null)
    list_file="${MODE_BACKUP_DIR}/hd_mode/video_settings/hd_mode_list.txt"

    _hd_push_mode() {
        local id="$1" text="$2"
        local existing
        [ -z "$id" ] && return
        [ "$id" = "max-640x480" ] && return
        [[ "$id" == Boot_* ]] && return
        case "$id" in
            *i.*|*i) return ;;
        esac
        for existing in "${HD_MODE_IDS[@]}"; do
            [ "$existing" = "$id" ] && return
        done
        HD_MODE_IDS+=("$id")
        HD_MODE_LABELS+=("$text")
    }

    if [ "$current" = "hd" ] && command -v batocera-resolution >/dev/null 2>&1; then
        local tmp
        tmp=$(mktemp)
        local screen
        screen=$(_hd_list_screen)
        if [ -n "$screen" ]; then
            batocera-resolution --screen "$screen" listModes > "$tmp" 2>/dev/null
        else
            batocera-resolution listModes > "$tmp" 2>/dev/null
        fi
        if [ -s "$tmp" ]; then
            mkdir -p "${MODE_BACKUP_DIR}/hd_mode/video_settings"
            {
                echo "STACK=$stack"
                while IFS= read -r line; do
                    [ -z "$line" ] && continue
                    mode_id="${line%%:*}"
                    label="${line#*:}"
                    [ "$mode_id" = "max-640x480" ] && continue
                    printf '%s:%s\n' "$mode_id" "$label"
                done < "$tmp"
            } > "$list_file"
            while IFS= read -r line; do
                [ -z "$line" ] && continue
                [[ "$line" == STACK=* ]] && continue
                mode_id="${line%%:*}"
                label="${line#*:}"
                _hd_push_mode "$mode_id" "$label"
            done < "$list_file"
            HD_MODES_SOURCE="live"
            _hd_record_connected_monitor
        fi
        rm -f "$tmp"
    fi

    if [ ${#HD_MODE_IDS[@]} -eq 0 ] && [ -f "$list_file" ]; then
        local saved_stack
        saved_stack=$(grep '^STACK=' "$list_file" 2>/dev/null | cut -d'=' -f2 | head -1)
        if [ "$saved_stack" = "$stack" ]; then
            while IFS= read -r line; do
                [ -z "$line" ] && continue
                [[ "$line" == STACK=* ]] && continue
                mode_id="${line%%:*}"
                label="${line#*:}"
                _hd_push_mode "$mode_id" "$label"
            done < "$list_file"
            [ ${#HD_MODE_IDS[@]} -gt 0 ] && HD_MODES_SOURCE="saved"
        fi
    fi

    if [ ${#HD_MODE_IDS[@]} -eq 0 ]; then
        _hd_push_mode "max-1280x720" "maximum 1280x720"
        _hd_push_mode "max-1920x1080" "maximum 1920x1080"
        _hd_push_mode "max-2560x1440" "maximum 2560x1440"
        _hd_push_mode "max-3440x1440" "maximum 3440x1440"
        _hd_push_mode "max-3840x2160" "maximum 3840x2160"
        HD_MODES_SOURCE="preset"
    fi

    [ ${#HD_MODE_IDS[@]} -gt 0 ]
}

# Function: show_hd_resolution_dialog
# Purpose: Pick the resolution restored on the next switch to HD
# Parameters: $1 - current mode id
# Returns: Selected mode id in SELECTED_HD_RES, 0 on success, 1 on cancel
show_hd_resolution_dialog() {
    local selected_res="$1"
    local stack stack_label hint
    stack=$(detect_hd_display_stack)
    if [ "$stack" = "wayland" ]; then
        stack_label="Wayland"
    else
        stack_label="X11"
    fi

    echo "[$(date +"%H:%M:%S")]: HD resolution selection started (stack=$stack)" >> "$LOG_FILE"

    if ! get_available_hd_modes; then
        dialog --title "Error" \
               --backtitle "HD/CRT Mode Switcher" \
               --msgbox "No HD resolutions are available." \
               8 50
        return 1
    fi

    local monitor_name
    monitor_name=$(_hd_saved_monitor_name)

    if [ "$HD_MODES_SOURCE" = "preset" ]; then
        hint="No HD monitor list has been saved yet.\nThese are resolution caps."
    elif [ "$HD_MODES_SOURCE" = "live" ]; then
        hint="HD monitor: ${monitor_name:-this display}\nRead from the monitor connected now.\nThis list is saved for CRT Mode.\nTo use a different HD monitor you must exit this app, plug in your desired monitor and relaunch the app."
    else
        hint="HD monitor: ${monitor_name:-last HD session}\nThis resolution list is for that monitor.\nPlug in the same monitor when you switch to HD.\nTo use a different HD monitor, change it in HD Mode after Batocera fully boots, then open the Mode Switcher."
    fi

    local default_item=""

    while true; do
        local menu_items=()
        local i
        for i in "${!HD_MODE_IDS[@]}"; do
            local marker=""
            if [ "${HD_MODE_IDS[$i]}" = "$selected_res" ]; then
                marker="  [SELECTED]"
            fi
            menu_items+=("${HD_MODE_IDS[$i]}" "$(_hd_menu_label "${HD_MODE_IDS[$i]}")${marker}")
        done
        menu_items+=("--------" "-----------------------------")
        menu_items+=("CONFIRM" "Proceed with selected")
        menu_items+=("CANCEL" "Go back")

        if [ -z "$default_item" ]; then
            if [ -n "$selected_res" ]; then
                default_item="CONFIRM"
            else
                default_item="${HD_MODE_IDS[0]}"
            fi
        fi

        local visible=$((${#HD_MODE_IDS[@]} + 3))
        [ "$visible" -gt 12 ] && visible=12

        local choice
        choice=$(dialog --title "HD Resolution Setup (${stack_label})" \
                       --backtitle "HD/CRT Mode Switcher" \
                       --default-item "$default_item" \
                       --no-cancel \
                       --no-ok \
                       --menu "${hint}\n\nSelect HD resolution:\n(Use UP/DOWN to navigate, B to select)" \
                       26 74 "$visible" \
                       "${menu_items[@]}" \
                       3>&1 1>&2 2>&3)

        local exit_code=$?
        if [ $exit_code -ne 0 ]; then
            return 1
        fi

        if [ "$choice" = "--------" ]; then
            default_item="CONFIRM"
            continue
        fi
        if [ "$choice" = "CANCEL" ]; then
            return 1
        fi
        if [ "$choice" = "CONFIRM" ]; then
            if ! _hd_resolution_usable "$selected_res"; then
                dialog --title "No Resolution Selected" \
                       --backtitle "HD/CRT Mode Switcher" \
                       --msgbox "You must select an HD resolution first.\n\nUse UP/DOWN to highlight a resolution, then press B to select it." \
                       10 55
                default_item="${HD_MODE_IDS[0]}"
                continue
            fi
            SELECTED_HD_RES="$selected_res"
            echo "[$(date +"%H:%M:%S")]: HD resolution confirmed: $selected_res (stack=$stack)" >> "$LOG_FILE"
            return 0
        fi

        selected_res="$choice"
        default_item="CONFIRM"
        echo "[$(date +"%H:%M:%S")]: User selected HD resolution: $selected_res" >> "$LOG_FILE"
    done
}

#######################################################################################
# Blind switch watcher (crt_mode_switch_watcher) - same HD backup gate as crt-mode-switch-combo.
# Defined in this module with the other Mode Switch Configuration dialogs (EDIT_HD / EDIT_CRT / EDIT_BOOT).
#######################################################################################
_hd_backup_exists() {
    local meta="/userdata/Batocera-CRT-Script-Backup/mode_backups/hd_mode/mode_metadata.txt"
    [ -f "$meta" ] && grep -q '^MODE=hd' "$meta" 2>/dev/null
}

_watcher_enabled() {
    local svcs
    svcs="$(/usr/bin/batocera-settings-get system.services 2>/dev/null)"
    echo " ${svcs} " | grep -q ' crt_mode_switch_watcher '
}

_modeswitcher_watcher_status_label() {
    if ! _hd_backup_exists; then
        echo "UNAVAILABLE"
    elif _watcher_enabled; then
        echo "ON"
    else
        echo "OFF"
    fi
}

# Function: show_watcher_page
# Purpose: Blind switch watcher config using the same select-then-confirm pattern as boot/output dialogs
# Returns: 0
show_watcher_page() {
    local selected_action=""
    local default_item=""

    if ! _hd_backup_exists; then
        dialog --title "Blind Switch Watcher" \
               --backtitle "HD/CRT Mode Switcher" \
               --msgbox "Enables a background service that watches for a button\ncombo and switches to HD Mode without needing a display.\nUseful when you power on away from a CRT.\n\nCombo: SELECT + START + L1 + L2 held 5 seconds.\n\nNOT AVAILABLE YET\nYou must complete one full HD/CRT round trip using the\nmode switcher first. This saves the HD settings that\nthe blind switch restores." \
               16 62
        return 0
    fi

    local current_state="OFF"
    _watcher_enabled && current_state="ON"

    while true; do
        local menu_items=()
        local on_marker="" off_marker=""

        if [ "$current_state" = "ON" ]; then
            on_marker="  [CURRENT]"
        else
            off_marker="  [CURRENT]"
        fi

        if [ "$selected_action" = "ENABLE" ]; then
            on_marker="  [SELECTED]"
        elif [ "$selected_action" = "DISABLE" ]; then
            off_marker="  [SELECTED]"
        fi

        menu_items+=("ENABLE" "Watcher ON$on_marker")
        menu_items+=("DISABLE" "Watcher OFF$off_marker")
        menu_items+=("--------" "─────────────────────────────")
        menu_items+=("CONFIRM" "Apply selected setting")
        menu_items+=("CANCEL" "Go back")

        if [ -z "$default_item" ]; then
            if [ "$current_state" = "ON" ]; then
                default_item="ENABLE"
            else
                default_item="DISABLE"
            fi
        fi

        local choice
        choice=$(dialog --title "Blind Switch Watcher Setup" \
                       --backtitle "HD/CRT Mode Switcher" \
                       --default-item "$default_item" \
                       --no-cancel \
                       --no-ok \
                       --menu "Enables a background service that watches for a button\ncombo and switches to HD Mode without needing a display.\nUseful when you power on away from a CRT.\n\nCombo: SELECT + START + L1 + L2 held 5 seconds.\nRequires one full HD/CRT round trip first." \
                       18 62 5 \
                       "${menu_items[@]}" \
                       3>&1 1>&2 2>&3)

        local exit_code=$?

        if [ $exit_code -ne 0 ]; then
            return 0
        fi

        if [ "$choice" = "--------" ]; then
            default_item="CONFIRM"
            continue
        fi

        if [ "$choice" = "CANCEL" ]; then
            return 0
        fi

        if [ "$choice" = "CONFIRM" ]; then
            if [ -z "$selected_action" ]; then
                dialog --title "No Change Selected" \
                       --backtitle "HD/CRT Mode Switcher" \
                       --msgbox "Select ENABLE or DISABLE first, then CONFIRM." \
                       7 55
                default_item="ENABLE"
                continue
            fi

            if [ "$selected_action" = "ENABLE" ] && [ "$current_state" = "ON" ]; then
                return 0
            fi
            if [ "$selected_action" = "DISABLE" ] && [ "$current_state" = "OFF" ]; then
                return 0
            fi

            if [ "$selected_action" = "ENABLE" ]; then
                if /usr/bin/batocera-services enable crt_mode_switch_watcher 2>/dev/null && \
                   /usr/bin/batocera-services start crt_mode_switch_watcher 2>/dev/null; then
                    dialog --title "Blind Switch Watcher" \
                           --backtitle "HD/CRT Mode Switcher" \
                           --msgbox "Watcher enabled and started.\n\nWill auto-start on every boot." \
                           8 50
                else
                    dialog --title "Error" \
                           --backtitle "HD/CRT Mode Switcher" \
                           --msgbox "Could not enable watcher. Try from SSH:\n  batocera-services enable crt_mode_switch_watcher\n  batocera-services start crt_mode_switch_watcher" \
                           10 62
                fi
            else
                /usr/bin/batocera-services stop crt_mode_switch_watcher 2>/dev/null || true
                if /usr/bin/batocera-services disable crt_mode_switch_watcher 2>/dev/null; then
                    dialog --title "Blind Switch Watcher" \
                           --backtitle "HD/CRT Mode Switcher" \
                           --msgbox "Watcher disabled and stopped.\n\nWill not start on next boot." \
                           8 50
                else
                    dialog --title "Error" \
                           --backtitle "HD/CRT Mode Switcher" \
                           --msgbox "Could not disable watcher. Try from SSH:\n  batocera-services stop crt_mode_switch_watcher\n  batocera-services disable crt_mode_switch_watcher" \
                           10 62
                fi
            fi
            return 0
        fi

        selected_action="$choice"
        default_item="CONFIRM"
    done
}

# Function: show_config_summary_dialog
# Purpose: Show summary of all configs with EDIT option
# Parameters: $1 - target_mode, $2 - hd_output, $3 - crt_output, $4 - crt_boot, $5 - hd_resolution
# Returns: Action in SUMMARY_ACTION variable ("confirm", "edit_hd", "edit_crt", "edit_boot", "edit_hd_res", "edit_watcher", "cancel")
show_config_summary_dialog() {
    local target_mode="$1"
    local hd_output="$2"
    local crt_output="$3"
    local crt_boot="$4"
    local hd_res="$5"

    while true; do
        local menu_items=()

        # Build summary display
        local mon
        mon=$(_hd_saved_monitor_name)
        [ -n "$mon" ] || mon="(not recorded)"
        local hd_display="HD Output:   $hd_output"
        local hd_monitor_display="HD Monitor:  $mon"
        local hd_res_display="HD Res:      $(_hd_res_label "$hd_res")"
        local crt_display="CRT Output:  $crt_output"
        local boot_display="CRT Boot:    $crt_boot"
        local watcher_display="Blind Switch Watcher:   $(_modeswitcher_watcher_status_label)"

        # Add markers for current mode
        if [ "$target_mode" = "hd" ]; then
            hd_display="$hd_display  << SWITCHING TO"
        else
            crt_display="$crt_display  << SWITCHING TO"
        fi

        menu_items+=("CONFIRM" ">>> Switch to $(get_mode_display_name "$target_mode")")

        # Add all EDIT options
        menu_items+=("EDIT_HD" "Edit HD Output ($hd_output)")
        if ! _hd_is_steam_deck; then
            menu_items+=("EDIT_HD_RES" "Edit HD Resolution ($(_hd_res_label "$hd_res"))")
        fi
        menu_items+=("EDIT_CRT" "Edit CRT Output ($crt_output)")
        menu_items+=("EDIT_BOOT" "Edit CRT Boot Resolution")
        menu_items+=("EDIT_WATCHER" "Edit Blind Switch Watcher")

        menu_items+=("--------" "-----------------------------")
        menu_items+=("CANCEL" "Return to EmulationStation")

        local choice exit_code
        choice=$(dialog --title "Mode Switch Configuration" \
                       --backtitle "HD/CRT Mode Switcher" \
                       --default-item "CONFIRM" \
                       --no-cancel \
                       --no-ok \
                       --menu "Current Configuration:\n\n$hd_display\n$hd_monitor_display\n$hd_res_display\n$crt_display\n$boot_display\n$watcher_display\n\nSelect action:" \
                       26 74 8 \
                       "${menu_items[@]}" \
                       3>&1 1>&2 2>&3)
        exit_code=$?
        choice="${choice//$'\r'/}"
        choice="${choice//$'\n'/}"
        choice="${choice#"${choice%%[![:space:]]*}"}"
        choice="${choice%"${choice##*[![:space:]]}"}"

        if [ $exit_code -ne 0 ]; then
            declare -g SUMMARY_ACTION="cancel"
            return 1
        fi

        case "$choice" in
            "CONFIRM")
                declare -g SUMMARY_ACTION="confirm"
                return 0
                ;;
            "EDIT_HD")
                declare -g SUMMARY_ACTION="edit_hd"
                return 0
                ;;
            "EDIT_CRT")
                declare -g SUMMARY_ACTION="edit_crt"
                return 0
                ;;
            "EDIT_BOOT")
                declare -g SUMMARY_ACTION="edit_boot"
                return 0
                ;;
            "EDIT_HD_RES")
                declare -g SUMMARY_ACTION="edit_hd_res"
                return 0
                ;;
            "EDIT_WATCHER")
                declare -g SUMMARY_ACTION="edit_watcher"
                return 0
                ;;
            "CANCEL"|"--------")
                declare -g SUMMARY_ACTION="cancel"
                return 1
                ;;
            *)
                declare -g SUMMARY_ACTION="cancel"
                return 1
                ;;
        esac
    done
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

    # EmulationStation's video menu stores the choice in es.resolution.
    # A Boot_ value or a mode id that maps to one wins over the saved sidecar,
    # so a change made in CRT shows up here. An HD choice such as
    # max-1920x1080 does not map to a Boot_ name and falls through.
    _boot_from_value() {
        local value="$1" display_name=""
        [ -z "$value" ] && return 1
        if [[ "$value" == Boot_* ]]; then
            printf '%s\n' "$value"
            return 0
        fi
        display_name=$(get_boot_display_name "$value")
        if [ -n "$display_name" ]; then
            printf '%s\n' "$display_name"
            return 0
        fi
        return 1
    }

    if [ -f "/userdata/system/batocera.conf" ]; then
        local key
        for key in es.resolution global.videomode; do
            boot_mode=$(grep "^${key}=" /userdata/system/batocera.conf 2>/dev/null | cut -d'=' -f2- | head -1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            if _boot_from_value "$boot_mode"; then
                return 0
            fi
        done
    fi

    # Sidecar (09A): when CRT to HD save overwrote video_mode.txt with
    # batocera-resolution currentMode, the Boot_ label is no longer in that file.
    local boot_display_file="${MODE_BACKUP_DIR}/crt_mode/video_settings/crt_boot_display.txt"
    if [ -f "$boot_display_file" ]; then
        local sidecar_line
        sidecar_line=$(grep -v '^[[:space:]]*$' "$boot_display_file" 2>/dev/null | head -1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ "$sidecar_line" == Boot_* ]]; then
            echo "$sidecar_line"
            return 0
        fi
    fi

    # Try CRT mode backup
    local backup_file="${MODE_BACKUP_DIR}/crt_mode/video_settings/video_mode.txt"
    if [ -f "$backup_file" ]; then
        boot_mode=$(grep '^global\.videomode=' "$backup_file" 2>/dev/null | cut -d'=' -f2- | head -1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if _boot_from_value "$boot_mode"; then
            return 0
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
    # Prefix fallback: currentMode reports lower precision (e.g. 769x576.50.00)
    # than videomodes.conf stores (e.g. 769x576.50.00060). Match if either is a
    # prefix of the other — they represent the same physical mode.
    for i in "${!BOOT_MODE_IDS[@]}"; do
        if [[ "${BOOT_MODE_IDS[$i]}" == "${mode_id}"* ]] || [[ "$mode_id" == "${BOOT_MODE_IDS[$i]}"* ]]; then
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
# Sets global variables: NEEDS_HD_CONFIG, NEEDS_CRT_CONFIG, NEEDS_BOOT_CONFIG, NEEDS_HD_RES, ALL_CONFIGURED
check_mandatory_configs() {
    local target_mode="$1"
    
    # Get current values
    local hd_output=$(get_current_hd_output)
    local crt_output=$(get_current_crt_backup_output)
    if [ -z "$crt_output" ]; then
        crt_output=$(get_current_crt_output)
    fi
    local crt_boot=$(get_crt_boot_resolution)
    local hd_res=$(get_saved_hd_resolution)
    get_available_hd_modes || true
    # While HD is running, EmulationStation's video menu is es.resolution.
    # global.videomode can stay on the previous exact mode (1920x1080.60.00)
    # after the menu is set to max-1920x1080. Prefer the menu value when it
    # is one of this monitor's saved modes. In CRT, es.resolution is the CRT
    # mode, so leave the saved HD choice alone.
    if [ "$(detect_current_mode 2>/dev/null)" = "hd" ]; then
        local live_key live_res id
        for live_key in es.resolution global.videomode; do
            live_res=$(grep "^${live_key}=" /userdata/system/batocera.conf 2>/dev/null | cut -d'=' -f2- | head -1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            _hd_resolution_usable "$live_res" || continue
            for id in "${HD_MODE_IDS[@]}"; do
                if [ "$id" = "$live_res" ]; then
                    hd_res="$live_res"
                    break 2
                fi
            done
        done
    fi
    if _hd_resolution_usable "$hd_res"; then
        local id found=0
        for id in "${HD_MODE_IDS[@]}"; do
            [ "$id" = "$hd_res" ] && found=1 && break
        done
        [ "$found" = 0 ] && hd_res=""
    fi
    # The Deck panel has one usable mode. Keep that mode and do not ask.
    if _hd_is_steam_deck; then
        local native
        native=$(_hd_panel_native_mode)
        [ -n "$native" ] && hd_res="$native"
    fi
    
    # Determine what's missing
    NEEDS_HD_CONFIG=false
    NEEDS_CRT_CONFIG=false
    NEEDS_BOOT_CONFIG=false
    NEEDS_HD_RES=false
    
    [ -z "$hd_output" ] && NEEDS_HD_CONFIG=true
    [ -z "$crt_output" ] && NEEDS_CRT_CONFIG=true
    [ -z "$crt_boot" ] && NEEDS_BOOT_CONFIG=true
    _hd_resolution_usable "$hd_res" || NEEDS_HD_RES=true
    
    # Check if all configured
    if [ "$NEEDS_HD_CONFIG" = false ] && [ "$NEEDS_CRT_CONFIG" = false ] && [ "$NEEDS_BOOT_CONFIG" = false ] && [ "$NEEDS_HD_RES" = false ]; then
        ALL_CONFIGURED=true
    else
        ALL_CONFIGURED=false
    fi
    
    # Store values for later use
    CURRENT_HD_OUTPUT="$hd_output"
    CURRENT_CRT_OUTPUT="$crt_output"
    CURRENT_CRT_BOOT="$crt_boot"
    CURRENT_HD_RES="$hd_res"
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
    
    echo "[$(date +"%H:%M:%S")]: Config check - HD: $CURRENT_HD_OUTPUT, CRT: $CURRENT_CRT_OUTPUT, Boot: $CURRENT_CRT_BOOT, HD res: $CURRENT_HD_RES" >> "$LOG_FILE"
    echo "[$(date +"%H:%M:%S")]: Needs - HD: $NEEDS_HD_CONFIG, CRT: $NEEDS_CRT_CONFIG, Boot: $NEEDS_BOOT_CONFIG, HD res: $NEEDS_HD_RES, All configured: $ALL_CONFIGURED" >> "$LOG_FILE"
    
    # Working variables for user selections
    local working_hd="$CURRENT_HD_OUTPUT"
    local working_crt="$CURRENT_CRT_OUTPUT"
    local working_boot="$CURRENT_CRT_BOOT"
    local working_hd_res="$CURRENT_HD_RES"
    
    # Track whether values are from saved config (true) or just selected (false)
    local hd_is_saved="false"
    local crt_is_saved="false"
    [ -n "$CURRENT_HD_OUTPUT" ] && hd_is_saved="true"
    [ -n "$CURRENT_CRT_OUTPUT" ] && crt_is_saved="true"
    
    # Main UI loop
    while true; do
        
        # If all configured, show summary with EDIT option
        if [ "$NEEDS_HD_CONFIG" = false ] && [ "$NEEDS_CRT_CONFIG" = false ] && [ "$NEEDS_BOOT_CONFIG" = false ] && [ "$NEEDS_HD_RES" = false ]; then
            
            # Final safety check - ensure all values are actually set
            if [ -z "$working_hd" ] || [ -z "$working_crt" ] || [ -z "$working_boot" ] || ! _hd_resolution_usable "$working_hd_res"; then
                dialog --title "Configuration Incomplete" \
                       --backtitle "HD/CRT Mode Switcher" \
                       --msgbox "ERROR: One or more configurations are missing.\n\nHD Output: ${working_hd:-NOT SET}\nHD Resolution: $(_hd_res_label "$working_hd_res")\nCRT Output: ${working_crt:-NOT SET}\nCRT Boot: ${working_boot:-NOT SET}\n\nPlease complete all selections." \
                       16 55
                
                # Reset flags for missing values
                [ -z "$working_hd" ] && NEEDS_HD_CONFIG=true
                [ -z "$working_crt" ] && NEEDS_CRT_CONFIG=true
                [ -z "$working_boot" ] && NEEDS_BOOT_CONFIG=true
                _hd_resolution_usable "$working_hd_res" || NEEDS_HD_RES=true
                continue
            fi
            
            show_config_summary_dialog "$target_mode" "$working_hd" "$working_crt" "$working_boot" "$working_hd_res"
            
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
                "edit_hd_res")
                    show_hd_resolution_dialog "$working_hd_res"
                    if [ $? -eq 0 ]; then
                        working_hd_res="$SELECTED_HD_RES"
                        NEEDS_HD_RES=false
                    fi
                    continue
                    ;;
                "edit_watcher")
                    show_watcher_page
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

            if [ "$NEEDS_HD_RES" = true ]; then
                show_hd_resolution_dialog "$working_hd_res"
                if [ $? -ne 0 ]; then
                    return 1
                fi
                working_hd_res="$SELECTED_HD_RES"
                NEEDS_HD_RES=false
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

            if [ "$NEEDS_HD_RES" = true ]; then
                show_hd_resolution_dialog "$working_hd_res"
                if [ $? -ne 0 ]; then
                    return 1
                fi
                working_hd_res="$SELECTED_HD_RES"
                NEEDS_HD_RES=false
            fi
        fi
        
        # After filling in missing configs, loop back to show summary
    done
    
    # Save all selections to backup files
    echo "[$(date +"%H:%M:%S")]: Saving selections - HD: $working_hd, HD res: $working_hd_res, CRT: $working_crt, Boot: $working_boot" >> "$LOG_FILE"
    
    # Save HD output
    mkdir -p "${MODE_BACKUP_DIR}/hd_mode/video_settings"
    echo "global.videooutput=$working_hd" > "${MODE_BACKUP_DIR}/hd_mode/video_settings/video_output.txt"

    # Save HD resolution into both files restore already writes.
    # default/auto is what misses and falls back to 640x480.
    if _hd_resolution_usable "$working_hd_res"; then
        local hd_stack
        hd_stack=$(detect_hd_display_stack)
        echo "global.videomode=$working_hd_res" > "${MODE_BACKUP_DIR}/hd_mode/video_settings/video_mode.txt"
        echo "es.resolution=$working_hd_res" > "${MODE_BACKUP_DIR}/hd_mode/video_settings/es_resolution.txt"
        echo "$hd_stack" > "${MODE_BACKUP_DIR}/hd_mode/video_settings/hd_display_stack.txt"
        echo "[$(date +"%H:%M:%S")]: Saved HD resolution $working_hd_res (stack=$hd_stack)" >> "$LOG_FILE"
    fi
    
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
    
    # When currently in CRT mode, use the actual mode string from batocera-resolution
    # instead of the videomodes.conf lookup.  videomodes.conf stores high-precision
    # refresh rates (e.g. 769x576.50.00060) but currentMode reports lower precision
    # (e.g. 769x576.50.00).  emulatorlauncher compares global.videomode with
    # currentMode — a mismatch triggers changeMode() which breaks the CRT display.
    local current_detected
    current_detected=$(detect_current_mode 2>/dev/null)
    
    if [ "$current_detected" = "crt" ] && command -v batocera-resolution >/dev/null 2>&1; then
        local synced_mode
        synced_mode=$(batocera-resolution currentMode 2>/dev/null)
        if [ -n "$synced_mode" ]; then
            echo "global.videomode=${synced_mode}" > "${MODE_BACKUP_DIR}/crt_mode/video_settings/video_mode.txt"
            echo "es.resolution=${synced_mode}" > "${MODE_BACKUP_DIR}/crt_mode/video_settings/es_resolution.txt"
            echo "[$(date +"%H:%M:%S")]: Saved synced CRT mode: $synced_mode (from currentMode, display: $working_boot)" >> "$LOG_FILE"
        elif [ -n "$boot_mode_id" ]; then
            echo "global.videomode=$boot_mode_id" > "${MODE_BACKUP_DIR}/crt_mode/video_settings/video_mode.txt"
            echo "es.resolution=$boot_mode_id" > "${MODE_BACKUP_DIR}/crt_mode/video_settings/es_resolution.txt"
            echo "[$(date +"%H:%M:%S")]: Saved boot mode ID: $boot_mode_id (currentMode unavailable)" >> "$LOG_FILE"
        else
            echo "global.videomode=$working_boot" > "${MODE_BACKUP_DIR}/crt_mode/video_settings/video_mode.txt"
            echo "es.resolution=$working_boot" > "${MODE_BACKUP_DIR}/crt_mode/video_settings/es_resolution.txt"
            echo "[$(date +"%H:%M:%S")]: WARNING: Could not convert '$working_boot' to mode ID, saved as-is" >> "$LOG_FILE"
        fi
    elif [ -n "$boot_mode_id" ]; then
        # Not in CRT mode (HD→CRT switch): always write the user's selection.
        # A prior version preserved existing video_mode.txt, but that prevented
        # boot resolution changes from taking effect.
        echo "global.videomode=$boot_mode_id" > "${MODE_BACKUP_DIR}/crt_mode/video_settings/video_mode.txt"
        echo "es.resolution=$boot_mode_id" > "${MODE_BACKUP_DIR}/crt_mode/video_settings/es_resolution.txt"
        echo "[$(date +"%H:%M:%S")]: Saved boot mode ID: $boot_mode_id (display: $working_boot)" >> "$LOG_FILE"
    else
        echo "global.videomode=$working_boot" > "${MODE_BACKUP_DIR}/crt_mode/video_settings/video_mode.txt"
        echo "es.resolution=$working_boot" > "${MODE_BACKUP_DIR}/crt_mode/video_settings/es_resolution.txt"
        echo "[$(date +"%H:%M:%S")]: WARNING: Could not convert '$working_boot' to mode ID, saved as-is" >> "$LOG_FILE"
    fi
    
    # Persist Boot_ display name for get_crt_boot_resolution when video_mode.txt is synced
    # to currentMode (CRT→HD path); see crt_boot_display.txt sidecar (09A).
    if [ -n "$working_boot" ] && [[ "$working_boot" == Boot_* ]]; then
        mkdir -p "${MODE_BACKUP_DIR}/crt_mode/video_settings"
        printf '%s\n' "$working_boot" > "${MODE_BACKUP_DIR}/crt_mode/video_settings/crt_boot_display.txt"
        echo "[$(date +"%H:%M:%S")]: Saved CRT boot display name (crt_boot_display.txt sidecar)" >> "$LOG_FILE"
    fi
    
    # Set output variables for caller
    USER_HD_OUTPUT="$working_hd"
    USER_CRT_OUTPUT="$working_crt"
    USER_CRT_BOOT="$working_boot"
    USER_HD_RES="$working_hd_res"
    
    echo "[$(date +"%H:%M:%S")]: Mode switch UI completed successfully" >> "$LOG_FILE"
    return 0
}

