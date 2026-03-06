#######################################################################################
# Module 03: Backup and Restore System
#######################################################################################

# Function: create_backup_directory_structure
# Purpose: Create backup directory structure for a mode
# Parameters: $1 - mode ("hd" or "crt")
create_backup_directory_structure() {
    local mode="$1"
    local backup_dir="${MODE_BACKUP_DIR}/${mode}_mode"
    
    mkdir -p "${backup_dir}/boot_configs"
    mkdir -p "${backup_dir}/userdata_configs"
    mkdir -p "${backup_dir}/emulator_configs"
    mkdir -p "${backup_dir}/video_settings"
    mkdir -p "${backup_dir}/overlay"
}

# Function: set_syslinux_boot_default
# Purpose: In dual-boot systems, change the DEFAULT line in all syslinux.cfg
#          files without restoring the entire file (preserves dual-boot structure)
# Parameters: $1 - target label ("batocera" or "crt")
set_syslinux_boot_default() {
    local target_label="$1"
    mount -o remount,rw /boot 2>/dev/null || true
    for f in /boot/EFI/batocera/syslinux.cfg \
             /boot/boot/syslinux.cfg \
             /boot/boot/syslinux/syslinux.cfg; do
        [ -f "$f" ] || continue
        sed -i "s/^DEFAULT .*/DEFAULT ${target_label}/" "$f"
        sed -i '/^[[:space:]]*MENU DEFAULT[[:space:]]*$/d' "$f"
        sed -i "/^LABEL ${target_label}\$/a\\\\tMENU DEFAULT" "$f"
        echo "[$(date +"%H:%M:%S")]: Set DEFAULT=${target_label} in $f" >> "$LOG_FILE"
    done
    local grub_cfg="/boot/EFI/BOOT/grub.cfg"
    if [ -f "$grub_cfg" ]; then
        if [ "$target_label" = "batocera" ]; then
            sed -i 's/set default="[0-9]*"/set default="0"/' "$grub_cfg"
        else
            sed -i 's/set default="[0-9]*"/set default="1"/' "$grub_cfg"
        fi
    fi
    mount -o remount,ro /boot 2>/dev/null || true
}

# Function: backup_overlay_file
# Purpose: Backup current overlay file to mode backup directory
# Parameters: $1 - mode ("hd" or "crt")
# Note: Overlay file contains all system-level changes (files in /etc/, /usr/, etc.)
backup_overlay_file() {
    local mode="$1"
    local backup_dir="${MODE_BACKUP_DIR}/${mode}_mode"
    local overlay_path="/boot/boot/overlay"
    local backup_overlay_path="${backup_dir}/overlay/overlay.${mode}"
    
    # Ensure overlay backup directory exists
    mkdir -p "${backup_dir}/overlay" 2>/dev/null || true
    
    # If overlay exists, save it to mode backup
    if [ -f "$overlay_path" ]; then
        echo "[$(date +"%H:%M:%S")]: Backing up overlay file to ${mode} mode backup..." >> "$LOG_FILE"
        cp -a "$overlay_path" "$backup_overlay_path" 2>/dev/null || {
            echo "[$(date +"%H:%M:%S")]: ERROR: Failed to backup overlay file" >> "$LOG_FILE"
            return 1
        }
        echo "[$(date +"%H:%M:%S")]: Successfully backed up overlay file (size: $(stat -c%s "$backup_overlay_path" 2>/dev/null || echo "unknown") bytes)" >> "$LOG_FILE"
    else
        echo "[$(date +"%H:%M:%S")]: No overlay file exists (system is vanilla)" >> "$LOG_FILE"
        # Remove backup overlay if it exists (cleanup)
        rm -f "$backup_overlay_path" 2>/dev/null || true
    fi
    
    return 0
}

# Function: restore_overlay_file
# Purpose: Restore overlay file from mode backup (or ensure missing for HD mode)
# Parameters: $1 - mode ("hd" or "crt")
# Note: HD mode should have no overlay (vanilla Batocera), CRT mode should have overlay with CRT Script changes
restore_overlay_file() {
    local mode="$1"
    local backup_dir="${MODE_BACKUP_DIR}/${mode}_mode"
    local overlay_path="/boot/boot/overlay"
    local backup_overlay_path="${backup_dir}/overlay/overlay.${mode}"
    
    # Mount boot partition as read-write
    mount -o remount,rw /boot 2>/dev/null || {
        echo "[$(date +"%H:%M:%S")]: ERROR: Failed to remount /boot as read-write" >> "$LOG_FILE"
        return 1
    }
    
    if [ "$mode" = "hd" ]; then
        # HD Mode: Restore HD overlay if user has HD-mode system changes, otherwise ensure missing (vanilla Batocera)
        if [ -f "$backup_overlay_path" ]; then
            echo "[$(date +"%H:%M:%S")]: HD Mode: Restoring user's HD-mode overlay..." >> "$LOG_FILE"
            cp -a "$backup_overlay_path" "$overlay_path" 2>/dev/null || {
                echo "[$(date +"%H:%M:%S")]: ERROR: Failed to restore HD-mode overlay" >> "$LOG_FILE"
            }
        else
            # No HD overlay backup - ensure overlay is missing for pure vanilla Batocera
            if [ -f "$overlay_path" ]; then
                echo "[$(date +"%H:%M:%S")]: HD Mode: Removing overlay file for vanilla Batocera..." >> "$LOG_FILE"
                rm -f "$overlay_path" 2>/dev/null || {
                    echo "[$(date +"%H:%M:%S")]: WARNING: Failed to remove overlay file" >> "$LOG_FILE"
                }
            else
                echo "[$(date +"%H:%M:%S")]: HD Mode: No overlay file (pure vanilla Batocera)" >> "$LOG_FILE"
            fi
        fi
    elif [ "$mode" = "crt" ]; then
        # CRT Mode: Restore CRT overlay with CRT Script customizations
        if [ -f "$backup_overlay_path" ]; then
            echo "[$(date +"%H:%M:%S")]: CRT Mode: Restoring CRT overlay with CRT Script customizations..." >> "$LOG_FILE"
            cp -a "$backup_overlay_path" "$overlay_path" 2>/dev/null || {
                echo "[$(date +"%H:%M:%S")]: ERROR: Failed to restore CRT overlay" >> "$LOG_FILE"
                mount -o remount,ro /boot 2>/dev/null || true
                return 1
            }
            echo "[$(date +"%H:%M:%S")]: Successfully restored CRT overlay (size: $(stat -c%s "$overlay_path" 2>/dev/null || echo "unknown") bytes)" >> "$LOG_FILE"
        else
            echo "[$(date +"%H:%M:%S")]: WARNING: No CRT overlay backup found - CRT Script may not be fully installed" >> "$LOG_FILE"
        fi
    fi
    
    # Sync (but don't remount read-only yet - let restore_mode_files handle that)
    sync 2>/dev/null || true
    
    return 0
}

# Function: remove_crt_script_files_only
# Purpose: Remove only CRT Script-specific files from /userdata/system/scripts, preserving user custom scripts
# Note: CRT Script files are: first_script.sh, 1_GunCon2.sh
remove_crt_script_files_only() {
    # Ensure directory exists (don't delete it)
    mkdir -p "/userdata/system/scripts" 2>/dev/null || true
    
    # Remove only CRT Script-specific files
    if [ -f "/userdata/system/scripts/first_script.sh" ]; then
        rm -f "/userdata/system/scripts/first_script.sh" 2>/dev/null || true
        echo "[$(date +"%H:%M:%S")]: Removed CRT Script file: first_script.sh" >> "$LOG_FILE"
    fi
    
    if [ -f "/userdata/system/scripts/1_GunCon2.sh" ]; then
        rm -f "/userdata/system/scripts/1_GunCon2.sh" 2>/dev/null || true
        echo "[$(date +"%H:%M:%S")]: Removed CRT Script file: 1_GunCon2.sh" >> "$LOG_FILE"
    fi
}

# Function: restore_crt_script_files
# Purpose: Restore CRT Script files from backup to /userdata/system/scripts
# Parameters: $1 - backup directory path
restore_crt_script_files() {
    local backup_scripts_dir="$1"
    
    # Ensure directory exists
    mkdir -p "/userdata/system/scripts" 2>/dev/null || true
    
    # Restore CRT Script files if they exist in backup
    if [ -f "${backup_scripts_dir}/first_script.sh" ]; then
        cp -a "${backup_scripts_dir}/first_script.sh" "/userdata/system/scripts/first_script.sh" 2>/dev/null || true
        chmod 755 "/userdata/system/scripts/first_script.sh" 2>/dev/null || true
        echo "[$(date +"%H:%M:%S")]: Restored CRT Script file: first_script.sh" >> "$LOG_FILE"
    fi
    
    if [ -f "${backup_scripts_dir}/1_GunCon2.sh" ]; then
        cp -a "${backup_scripts_dir}/1_GunCon2.sh" "/userdata/system/scripts/1_GunCon2.sh" 2>/dev/null || true
        chmod 755 "/userdata/system/scripts/1_GunCon2.sh" 2>/dev/null || true
        echo "[$(date +"%H:%M:%S")]: Restored CRT Script file: 1_GunCon2.sh" >> "$LOG_FILE"
    fi
}

# Function: get_video_output_xrandr
# Purpose: Get the xrandr video output name (e.g., DP-1, HDMI-1) for use in scripts
# Returns: Video output name via echo, empty string if not found
# Strategy: Try multiple methods to determine the video output
get_video_output_xrandr() {
    local video_output=""
    
    # Method 1: Extract from existing GunCon2_Calibration.sh if it exists
    if [ -f "$CRT_ROMS/crt/GunCon2_Calibration.sh" ]; then
        video_output=$(grep '--output' "$CRT_ROMS/crt/GunCon2_Calibration.sh" 2>/dev/null | sed 's/.*--output \([^ ]*\).*/\1/' | head -1)
        if [ -n "$video_output" ]; then
            echo "$video_output"
            return 0
        fi
    fi
    
    # Method 2: Extract from batocera.conf (global.videooutput)
    if [ -f "/userdata/system/batocera.conf" ]; then
        video_output=$(grep "^global.videooutput=" /userdata/system/batocera.conf 2>/dev/null | cut -d'=' -f2 | head -1)
        if [ -n "$video_output" ]; then
            echo "$video_output"
            return 0
        fi
    fi
    
    # Method 3: Try to detect from xrandr (may not work without X11)
    if command -v xrandr >/dev/null 2>&1; then
        export DISPLAY=:0.0 2>/dev/null || true
        # Try xrandr --query to find connected displays
        video_output=$(xrandr --query 2>/dev/null | grep " connected" | grep -v " disconnected" | awk '{print $1}' | head -1)
        if [ -n "$video_output" ]; then
            echo "$video_output"
            return 0
        fi
    fi
    
    # Method 4: Try to get from batocera-resolution if available
    if command -v batocera-resolution >/dev/null 2>&1; then
        export DISPLAY=:0.0 2>/dev/null || true
        video_output=$(batocera-resolution listOutputs 2>/dev/null | grep -v "^$" | head -1)
        if [ -n "$video_output" ]; then
            echo "$video_output"
            return 0
        fi
    fi
    
    # If all methods fail, return empty string
    echo ""
    return 1
}

# Function: backup_video_settings
# Purpose: Backup VIDEO OUTPUT and VIDEO MODE settings from batocera.conf
# Parameters: $1 - mode ("hd" or "crt")
# Note: Only overwrites files that are empty (preserves UI selections from run_mode_switch_ui)
backup_video_settings() {
    local mode="$1"
    local backup_dir="${MODE_BACKUP_DIR}/${mode}_mode/video_settings"
    
    mkdir -p "$backup_dir"
    
    if [ -f "/userdata/system/batocera.conf" ]; then
        # Extract VIDEO OUTPUT settings
        # Note: Only backup if file doesn't exist or is empty (preserve UI selections)
        # Note: grep patterns must include '=' to avoid matching videooutput2/3 with videooutput
        if [ ! -s "${backup_dir}/video_output.txt" ]; then
            grep "^global.videooutput=" /userdata/system/batocera.conf > "${backup_dir}/video_output.txt" 2>/dev/null || true
        fi
        if [ ! -s "${backup_dir}/video_output2.txt" ]; then
            grep "^global.videooutput2=" /userdata/system/batocera.conf > "${backup_dir}/video_output2.txt" 2>/dev/null || true
        fi
        if [ ! -s "${backup_dir}/video_output3.txt" ]; then
            grep "^global.videooutput3=" /userdata/system/batocera.conf > "${backup_dir}/video_output3.txt" 2>/dev/null || true
        fi
        
        # Extract VIDEO MODE setting (only if not already set by UI)
        if [ ! -s "${backup_dir}/video_mode.txt" ]; then
            if [ "$mode" = "crt" ] && command -v batocera-resolution >/dev/null 2>&1; then
                # For CRT: use the actual current mode string from batocera-resolution.
                # batocera.conf may store a higher-precision refresh rate (e.g. 769x576.50.00060)
                # than what batocera-resolution currentMode reports (e.g. 769x576.50.00).
                # If these don't match, emulatorlauncher triggers a spurious video mode change
                # every time a CRT tool launches, which disrupts the display pipeline.
                local current_mode
                current_mode=$(batocera-resolution currentMode 2>/dev/null)
                if [ -n "$current_mode" ]; then
                    echo "global.videomode=${current_mode}" > "${backup_dir}/video_mode.txt"
                else
                    grep "^global.videomode" /userdata/system/batocera.conf > "${backup_dir}/video_mode.txt" 2>/dev/null || true
                fi
            else
                grep "^global.videomode" /userdata/system/batocera.conf > "${backup_dir}/video_mode.txt" 2>/dev/null || true
            fi
        fi
        
        # Query available outputs and modes (always update these)
        if command -v batocera-resolution >/dev/null 2>&1; then
            batocera-resolution listOutputs > "${backup_dir}/available_outputs.txt" 2>/dev/null || true
            batocera-resolution listModes > "${backup_dir}/available_modes.txt" 2>/dev/null || true
        fi
    fi
}

# Function: restore_video_settings
# Purpose: Restore VIDEO OUTPUT and VIDEO MODE settings
#          Writes to both batocera.conf AND batocera-boot.conf
#          (ES checks both files for video mode settings)
# Parameters: $1 - mode ("hd" or "crt")
restore_video_settings() {
    local mode="$1"
    local backup_dir="${MODE_BACKUP_DIR}/${mode}_mode/video_settings"
    
    if [ ! -d "$backup_dir" ]; then
        echo "Warning: Video settings backup not found for $mode mode" >> "$LOG_FILE"
        return 1
    fi
    
    if [ ! -f "/userdata/system/batocera.conf" ]; then
        echo "Warning: batocera.conf not found" >> "$LOG_FILE"
        return 1
    fi
    
    # Restore VIDEO OUTPUT settings
    if [ -f "${backup_dir}/video_output.txt" ]; then
        local video_output_line=$(cat "${backup_dir}/video_output.txt" | head -1)
        if [ -n "$video_output_line" ]; then
            # Update or add global.videooutput line
            # Note: grep pattern must include '=' to avoid matching global.videooutput2/3
            if grep -q "^global.videooutput=" /userdata/system/batocera.conf 2>/dev/null; then
                sed -i "s|^global.videooutput=.*|$video_output_line|" /userdata/system/batocera.conf
            else
                echo "$video_output_line" >> /userdata/system/batocera.conf
            fi
        fi
    fi
    
    # Restore VIDEO OUTPUT2
    if [ -f "${backup_dir}/video_output2.txt" ]; then
        local video_output2_line=$(cat "${backup_dir}/video_output2.txt" | head -1)
        if [ -n "$video_output2_line" ]; then
            if grep -q "^global.videooutput2=" /userdata/system/batocera.conf 2>/dev/null; then
                sed -i "s|^global.videooutput2=.*|$video_output2_line|" /userdata/system/batocera.conf
            else
                echo "$video_output2_line" >> /userdata/system/batocera.conf
            fi
        fi
    fi
    
    # Restore VIDEO OUTPUT3
    if [ -f "${backup_dir}/video_output3.txt" ]; then
        local video_output3_line=$(cat "${backup_dir}/video_output3.txt" | head -1)
        if [ -n "$video_output3_line" ]; then
            if grep -q "^global.videooutput3=" /userdata/system/batocera.conf 2>/dev/null; then
                sed -i "s|^global.videooutput3=.*|$video_output3_line|" /userdata/system/batocera.conf
            else
                echo "$video_output3_line" >> /userdata/system/batocera.conf
            fi
        fi
    fi
    
    # Restore VIDEO MODE setting
    if [ -f "${backup_dir}/video_mode.txt" ]; then
        local video_mode_line=$(cat "${backup_dir}/video_mode.txt" | head -1)
        if [ -n "$video_mode_line" ]; then
            # Extract just the mode ID value
            local mode_id=$(echo "$video_mode_line" | cut -d'=' -f2)
            
            # Write to batocera.conf (what ES reads for display)
            if grep -q "^global.videomode=" /userdata/system/batocera.conf 2>/dev/null; then
                sed -i "s|^global.videomode=.*|$video_mode_line|" /userdata/system/batocera.conf
            else
                echo "$video_mode_line" >> /userdata/system/batocera.conf
            fi
            
            # CRITICAL: Write es.resolution to BOTH config files
            # ES checks both batocera.conf AND batocera-boot.conf
            if [ -n "$mode_id" ]; then
                # Write to batocera.conf
                if grep -q "^es.resolution=" /userdata/system/batocera.conf 2>/dev/null; then
                    sed -i "s|^es.resolution=.*|es.resolution=$mode_id|" /userdata/system/batocera.conf
                else
                    echo "es.resolution=$mode_id" >> /userdata/system/batocera.conf
                fi
                
                # Write to batocera-boot.conf (ensure /boot is writable)
                mount -o remount,rw /boot 2>/dev/null || true
                if grep -q "^es.resolution=" /boot/batocera-boot.conf 2>/dev/null; then
                    sed -i "s|^es.resolution=.*|es.resolution=$mode_id|" /boot/batocera-boot.conf
                else
                    echo "es.resolution=$mode_id" >> /boot/batocera-boot.conf
                fi
                echo "[$(date +"%H:%M:%S")]: Set es.resolution=$mode_id in both config files" >> "$LOG_FILE"
            fi
        fi
    else
        # No video_mode.txt - for HD mode, clear es.resolution to use auto
        if [ "$mode" = "hd" ]; then
            # Clear es.resolution from batocera.conf
            if grep -q "^es.resolution=" /userdata/system/batocera.conf 2>/dev/null; then
                sed -i '/^es.resolution=/d' /userdata/system/batocera.conf
            fi
            # Clear global.videomode for HD auto mode
            if grep -q "^global.videomode=" /userdata/system/batocera.conf 2>/dev/null; then
                sed -i '/^global.videomode=/d' /userdata/system/batocera.conf
            fi
            
            # Clear es.resolution from batocera-boot.conf
            mount -o remount,rw /boot 2>/dev/null || true
            if grep -q "^es.resolution=" /boot/batocera-boot.conf 2>/dev/null; then
                sed -i "s|^es.resolution=.*|es.resolution=|" /boot/batocera-boot.conf
            fi
            echo "[$(date +"%H:%M:%S")]: Cleared es.resolution from both config files for HD auto mode" >> "$LOG_FILE"
        fi
    fi
}

# Function: backup_mode_files
# Purpose: Backup current mode's userdata files only (no system overlay files)
# Parameters: $1 - mode ("hd" or "crt")
# Returns: 0 on success, 1 on failure
# 
# REFACTORED: Userdata-only approach per developer feedback
# - No longer backing up system binaries, Python scripts, or X11 configs
# - Focus on /userdata files that differ between modes
# - Move entire folders instead of individual files
backup_mode_files() {
    local mode="$1"
    local backup_dir="${MODE_BACKUP_DIR}/${mode}_mode"
    
    echo "[$(date +"%H:%M:%S")]: Starting backup for $mode mode (userdata-only approach)" >> "$LOG_FILE"
    
    # Create directory structure
    create_backup_directory_structure "$mode"
    
    # Backup video settings metadata
    backup_video_settings "$mode"
    
    #############################################################################
    # BOOT CONFIGS (Only syslinux.cfg - needed for EDID and output forcing)
    # Dual-boot: skip syslinux backup — the install script manages the
    # multi-entry structure; mode_switcher only flips the DEFAULT line.
    #############################################################################
    
    if is_dualboot_system; then
        echo "[$(date +"%H:%M:%S")]: Dual-boot: skipping syslinux.cfg backup (managed by install script)" >> "$LOG_FILE"
    else
        mount -o remount,rw /boot 2>/dev/null || true
        
        # For HD Mode: Use CRT Script factory backup as source
        if [ "$mode" = "hd" ]; then
            if [ -d "$CRT_BACKUP_DIR" ]; then
                if [ -f "${CRT_BACKUP_DIR}/boot/boot/syslinux.cfg" ]; then
                    mkdir -p "${backup_dir}/boot_configs/boot"
                    cp -a "${CRT_BACKUP_DIR}/boot/boot/syslinux.cfg" "${backup_dir}/boot_configs/boot/syslinux.cfg" 2>/dev/null || true
                    echo "[$(date +"%H:%M:%S")]: HD Mode: Backed up factory syslinux.cfg" >> "$LOG_FILE"
                fi
                # Backup other syslinux variants
                for syslinux_path in "EFI/batocera/syslinux.cfg" "EFI/BOOT/syslinux.cfg"; do
                    if [ -f "${CRT_BACKUP_DIR}/boot/${syslinux_path}" ]; then
                        mkdir -p "${backup_dir}/boot_configs/$(dirname "$syslinux_path")"
                        cp -a "${CRT_BACKUP_DIR}/boot/${syslinux_path}" "${backup_dir}/boot_configs/${syslinux_path}" 2>/dev/null || true
                    fi
                done
            fi
        fi
        
        # For CRT Mode: Backup current syslinux.cfg (with EDID parameters)
        if [ "$mode" = "crt" ]; then
            if [ -f "/boot/boot/syslinux.cfg" ]; then
                mkdir -p "${backup_dir}/boot_configs/boot"
                cp -a "/boot/boot/syslinux.cfg" "${backup_dir}/boot_configs/boot/syslinux.cfg" 2>/dev/null || true
                echo "[$(date +"%H:%M:%S")]: CRT Mode: Backed up syslinux.cfg with EDID parameters" >> "$LOG_FILE"
            fi
            # Backup other syslinux variants
            for syslinux_path in "EFI/batocera/syslinux.cfg" "EFI/BOOT/syslinux.cfg"; do
                if [ -f "/boot/${syslinux_path}" ]; then
                    mkdir -p "${backup_dir}/boot_configs/$(dirname "$syslinux_path")"
                    cp -a "/boot/${syslinux_path}" "${backup_dir}/boot_configs/${syslinux_path}" 2>/dev/null || true
                fi
            done
            
            # Backup boot-custom.sh if present
            if [ -f "/boot/boot-custom.sh" ]; then
                cp -a "/boot/boot-custom.sh" "${backup_dir}/boot_configs/boot-custom.sh" 2>/dev/null || true
                echo "[$(date +"%H:%M:%S")]: CRT Mode: Backed up boot-custom.sh" >> "$LOG_FILE"
            fi
        fi
    fi
    
    #############################################################################
    # USERDATA SYSTEM CONFIGS (Mode-specific settings)
    #############################################################################
    
    mkdir -p "${backup_dir}/userdata_configs"
    
    # batocera.conf (CRITICAL - contains all video/emulator settings)
    if [ -f "/userdata/system/batocera.conf" ]; then
        cp -a "/userdata/system/batocera.conf" "${backup_dir}/userdata_configs/batocera.conf" 2>/dev/null || true
        echo "[$(date +"%H:%M:%S")]: Backed up batocera.conf" >> "$LOG_FILE"
    fi
    
    # Mode-specific userdata files
    if [ "$mode" = "crt" ]; then
        [ -f "/userdata/system/videomodes.conf" ] && cp -a "/userdata/system/videomodes.conf" "${backup_dir}/userdata_configs/videomodes.conf" 2>/dev/null || true
        [ -f "/userdata/system/es.arg.override" ] && cp -a "/userdata/system/es.arg.override" "${backup_dir}/userdata_configs/es.arg.override" 2>/dev/null || true
        [ -f "/userdata/system/99-nvidia.conf" ] && cp -a "/userdata/system/99-nvidia.conf" "${backup_dir}/userdata_configs/99-nvidia.conf" 2>/dev/null || true
    fi
    
    #############################################################################
    # SCRIPTS FOLDER (Backup contents - will restore per-file to preserve user custom scripts)
    #############################################################################
    
    if [ -d "/userdata/system/scripts" ]; then
        mkdir -p "${backup_dir}/userdata_configs"
        cp -ra "/userdata/system/scripts" "${backup_dir}/userdata_configs/scripts" 2>/dev/null || true
        echo "[$(date +"%H:%M:%S")]: Backed up /userdata/system/scripts folder contents" >> "$LOG_FILE"
    fi
    
    #############################################################################
    # CRT TOOLS - GunCon2_Calibration.sh (CRT Mode only)
    #############################################################################
    
    if [ "$mode" = "crt" ]; then
        mkdir -p "${backup_dir}/userdata_configs"
        if [ -f "$CRT_ROMS/crt/GunCon2_Calibration.sh" ]; then
            cp -a "$CRT_ROMS/crt/GunCon2_Calibration.sh" "${backup_dir}/userdata_configs/GunCon2_Calibration.sh" 2>/dev/null || true
            echo "[$(date +"%H:%M:%S")]: Backed up GunCon2_Calibration.sh" >> "$LOG_FILE"
        fi
    fi
    
    #############################################################################
    # OVERLAY FILE (Backup system overlay containing all /etc/ and /usr/ changes)
    # Dual-boot: skip — each boot environment carries its own overlay
    # (Wayland at /boot/boot/overlay, CRT at /boot/crt/overlay)
    #############################################################################
    
    if is_dualboot_system; then
        echo "[$(date +"%H:%M:%S")]: Dual-boot: skipping overlay backup (each kernel has its own overlay)" >> "$LOG_FILE"
    else
        backup_overlay_file "$mode"
    fi
    
    #############################################################################
    # EMULATOR CONFIGS (Move entire folders between modes)
    #############################################################################
    
    mkdir -p "${backup_dir}/emulator_configs"
    
    # MAME folder (contains orientation-specific INI files)
    if [ -d "/userdata/system/configs/mame" ]; then
        cp -ra "/userdata/system/configs/mame" "${backup_dir}/emulator_configs/mame" 2>/dev/null || true
        echo "[$(date +"%H:%M:%S")]: Backed up entire MAME configs folder" >> "$LOG_FILE"
    fi
    
    # RetroArch folder (CRT-specific settings)
    if [ -d "/userdata/system/configs/retroarch" ]; then
        cp -ra "/userdata/system/configs/retroarch" "${backup_dir}/emulator_configs/retroarch" 2>/dev/null || true
        echo "[$(date +"%H:%M:%S")]: Backed up entire RetroArch configs folder" >> "$LOG_FILE"
    fi
    
    # EmulationStation settings (for AMD R9 instant transitions workaround)
    if [ -f "/userdata/system/configs/emulationstation/es_settings.cfg" ]; then
        mkdir -p "${backup_dir}/emulator_configs/emulationstation"
        cp -a "/userdata/system/configs/emulationstation/es_settings.cfg" "${backup_dir}/emulator_configs/emulationstation/es_settings.cfg" 2>/dev/null || true
        echo "[$(date +"%H:%M:%S")]: Backed up es_settings.cfg" >> "$LOG_FILE"
    fi
    
    # CRT Mode: Also backup es_systems_crt.cfg
    if [ "$mode" = "crt" ]; then
        if [ -f "/userdata/system/configs/emulationstation/es_systems_crt.cfg" ]; then
            mkdir -p "${backup_dir}/emulator_configs/emulationstation"
            cp -a "/userdata/system/configs/emulationstation/es_systems_crt.cfg" "${backup_dir}/emulator_configs/emulationstation/es_systems_crt.cfg" 2>/dev/null || true
            echo "[$(date +"%H:%M:%S")]: Backed up es_systems_crt.cfg" >> "$LOG_FILE"
        fi
    fi
    
    #############################################################################
    # Create metadata file
    #############################################################################
    
    create_backup_metadata "$mode" "$backup_dir"
    
    echo "[$(date +"%H:%M:%S")]: Backup completed for $mode mode (userdata-only)" >> "$LOG_FILE"
    return 0
}

# Function: create_backup_metadata
# Purpose: Create metadata file for backup
# Parameters: $1 - mode, $2 - backup directory
create_backup_metadata() {
    local mode="$1"
    local backup_dir="$2"
    local metadata_file="${backup_dir}/mode_metadata.txt"
    
    {
        echo "MODE=$mode"
        echo "TIMESTAMP=$(date -Iseconds)"
        echo "BATOCERA_VERSION=$(batocera-es-swissknife --version 2>/dev/null || echo 'unknown')"
        
        # Video settings
        if [ -f "/userdata/system/batocera.conf" ]; then
            grep "^global.videooutput" /userdata/system/batocera.conf | head -1 | cut -d'=' -f2 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' > /tmp/video_output.txt 2>/dev/null || true
            echo "VIDEO_OUTPUT=$(cat /tmp/video_output.txt 2>/dev/null || echo '')"
            rm -f /tmp/video_output.txt
            
            grep "^global.videomode" /userdata/system/batocera.conf | head -1 | cut -d'=' -f2 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' > /tmp/video_mode.txt 2>/dev/null || true
            echo "VIDEO_MODE=$(cat /tmp/video_mode.txt 2>/dev/null || echo '')"
            rm -f /tmp/video_mode.txt
        fi
        
        # Monitor profile (if CRT mode)
        if [ "$mode" = "crt" ] && [ -f "/etc/switchres.ini" ]; then
            grep "^monitor" /etc/switchres.ini | head -1 | awk '{print $2}' > /tmp/monitor_profile.txt 2>/dev/null || true
            echo "MONITOR_PROFILE=$(cat /tmp/monitor_profile.txt 2>/dev/null || echo 'none')"
            rm -f /tmp/monitor_profile.txt
        else
            echo "MONITOR_PROFILE=none"
        fi
        
        # Backup size
        local backup_size=$(du -sb "$backup_dir" 2>/dev/null | cut -f1 || echo "0")
        echo "BACKUP_SIZE_BYTES=$backup_size"
        
        # File count
        local file_count=$(find "$backup_dir" -type f 2>/dev/null | wc -l || echo "0")
        echo "BACKUP_FILES_COUNT=$file_count"
    } > "$metadata_file"
    
    chmod 644 "$metadata_file"
}

# Function: create_monitor_config
# Purpose: Dynamically create 10-monitor.conf based on batocera.conf settings
# Parameters: $1 - mode ("hd" or "crt")
# Returns: 0 on success, 1 on failure
# Function: restore_mode_files
# Purpose: Restore userdata files for target mode (userdata-only approach)
# Parameters: $1 - mode ("hd" or "crt")
# Returns: 0 on success, 1 on failure
#
# REFACTORED: Userdata-only approach per developer feedback
# - No longer restoring system binaries, Python scripts, or X11 configs
# - Focus on /userdata files and /boot/syslinux.cfg only
# - Move entire folders instead of individual files
# - Rely on boot-custom.sh for X11 config generation (CRT Mode)
restore_mode_files() {
    local mode="$1"
    local backup_dir="${MODE_BACKUP_DIR}/${mode}_mode"
    
    echo "[$(date +"%H:%M:%S")]: Starting restore for $mode mode (userdata-only approach)" >> "$LOG_FILE"
    
    if [ ! -d "$backup_dir" ]; then
        echo "Error: Backup directory not found for $mode mode" >> "$LOG_FILE"
        return 1
    fi
    
    # Determine source mode (the mode we're switching FROM)
    local source_mode=""
    if [ "$mode" = "hd" ]; then
        source_mode="crt"
    else
        source_mode="hd"
    fi
    local source_backup_dir="${MODE_BACKUP_DIR}/${source_mode}_mode"
    
    # Remount /boot as read-write if needed
    if ! mount -o remount,rw /boot 2>/dev/null; then
        echo "[$(date +"%H:%M:%S")]: ERROR: Failed to remount /boot as read-write" >> "$LOG_FILE"
        return 1
    fi
    
    #############################################################################
    # RESTORE OVERLAY FILE FIRST (Must be done before other operations)
    # Overlay contains all system-level changes (files in /etc/, /usr/, etc.)
    # Dual-boot: skip — each boot environment carries its own overlay
    #############################################################################
    
    if is_dualboot_system; then
        if [ "$mode" = "hd" ]; then
            # HD restore: delete /boot/boot/overlay so the Wayland kernel boots
            # from factory squashfs.  batocera-save-overlay was patched to write
            # CRT changes to /boot/crt/overlay, but any earlier contamination
            # (or a first-run before the patch) must be cleaned here.
            mount -o remount,rw /boot 2>/dev/null || true
            if [ -f /boot/boot/overlay ]; then
                rm -f /boot/boot/overlay
                echo "[$(date +"%H:%M:%S")]: Dual-boot HD: deleted /boot/boot/overlay for clean Wayland boot" >> "$LOG_FILE"
            else
                echo "[$(date +"%H:%M:%S")]: Dual-boot HD: /boot/boot/overlay already absent" >> "$LOG_FILE"
            fi
            mount -o remount,ro /boot 2>/dev/null || true
        else
            echo "[$(date +"%H:%M:%S")]: Dual-boot CRT: overlay at /boot/crt/overlay managed by boot environment" >> "$LOG_FILE"
        fi
    else
        restore_overlay_file "$mode"
    fi
    
    #############################################################################
    # RESTORE BASED ON MODE
    #############################################################################
    
    if [ "$mode" = "hd" ]; then
        #########################################################################
        # HD MODE RESTORE (Userdata-only approach)
        #########################################################################
        
        echo "[$(date +"%H:%M:%S")]: HD Mode: Restoring factory/clean state" >> "$LOG_FILE"
        
        # Determine whether to use CRT Script factory backup or HD mode backup
        # (must be set before the syslinux gate so batocera.conf restore can use it)
        local use_crt_backup=false
        if [ ! -f "${backup_dir}/userdata_configs/batocera.conf" ] && [ -d "$CRT_BACKUP_DIR" ]; then
            use_crt_backup=true
            echo "[$(date +"%H:%M:%S")]: HD Mode backup sparse, will use CRT Script factory backup for batocera.conf" >> "$LOG_FILE"
        fi
        
        # 1. RESTORE SYSLINUX.CFG
        if is_dualboot_system; then
            # Dual-boot: just flip DEFAULT to batocera (preserves dual-boot structure)
            set_syslinux_boot_default "batocera"
        else
            # Single-boot: restore entire factory syslinux.cfg
            
            if [ "$use_crt_backup" = true ]; then
                if [ -f "${CRT_BACKUP_DIR}/boot/boot/syslinux.cfg" ]; then
                    mkdir -p "/boot/boot"
                    if cp -a "${CRT_BACKUP_DIR}/boot/boot/syslinux.cfg" "/boot/boot/syslinux.cfg" 2>/dev/null; then
                        chmod 644 "/boot/boot/syslinux.cfg" 2>/dev/null || true
                        echo "[$(date +"%H:%M:%S")]: Restored factory syslinux.cfg" >> "$LOG_FILE"
                    else
                        echo "[$(date +"%H:%M:%S")]: ERROR: Failed to copy factory syslinux.cfg (boot partition may be read-only)" >> "$LOG_FILE"
                        return 1
                    fi
                fi
                for syslinux_path in "EFI/batocera/syslinux.cfg" "EFI/BOOT/syslinux.cfg"; do
                    if [ -f "${CRT_BACKUP_DIR}/boot/${syslinux_path}" ]; then
                        mkdir -p "/boot/$(dirname "$syslinux_path")"
                        cp -a "${CRT_BACKUP_DIR}/boot/${syslinux_path}" "/boot/${syslinux_path}" 2>/dev/null || true
                        chmod 644 "/boot/${syslinux_path}" 2>/dev/null || true
                    fi
                done
            else
                if [ -f "${backup_dir}/boot_configs/boot/syslinux.cfg" ]; then
                    mkdir -p "/boot/boot"
                    if cp -a "${backup_dir}/boot_configs/boot/syslinux.cfg" "/boot/boot/syslinux.cfg" 2>/dev/null; then
                        chmod 644 "/boot/boot/syslinux.cfg" 2>/dev/null || true
                        echo "[$(date +"%H:%M:%S")]: Restored syslinux.cfg from HD Mode backup" >> "$LOG_FILE"
                    else
                        echo "[$(date +"%H:%M:%S")]: ERROR: Failed to copy syslinux.cfg from HD Mode backup (boot partition may be read-only)" >> "$LOG_FILE"
                        return 1
                    fi
                fi
                for syslinux_path in "EFI/batocera/syslinux.cfg" "EFI/BOOT/syslinux.cfg"; do
                    if [ -f "${backup_dir}/boot_configs/${syslinux_path}" ]; then
                        mkdir -p "/boot/$(dirname "$syslinux_path")"
                        cp -a "${backup_dir}/boot_configs/${syslinux_path}" "/boot/${syslinux_path}" 2>/dev/null || true
                        chmod 644 "/boot/${syslinux_path}" 2>/dev/null || true
                    fi
                done
            fi
        fi
        
        # 2. RESTORE USERDATA SYSTEM CONFIGS
        # Preserve VNC settings from source mode's backup (they should persist across mode switches)
        local vnc_temp_file="/tmp/vnc_settings_$$.txt"
        # Try to extract VNC from source mode's backup first (most reliable)
        if [ -f "${source_backup_dir}/userdata_configs/batocera.conf" ]; then
            grep -E "^global\.vnc\." "${source_backup_dir}/userdata_configs/batocera.conf" > "$vnc_temp_file" 2>/dev/null || true
        fi
        # Fallback to current batocera.conf if source backup doesn't have VNC
        if [ ! -s "$vnc_temp_file" ] && [ -f "/userdata/system/batocera.conf" ]; then
            grep -E "^global\.vnc\." /userdata/system/batocera.conf > "$vnc_temp_file" 2>/dev/null || true
        fi
        
        if [ "$use_crt_backup" = true ]; then
            # Use CRT Script factory backup for batocera.conf
            if [ -f "${CRT_BACKUP_DIR}/userdata/system/batocera.conf" ]; then
                cp -a "${CRT_BACKUP_DIR}/userdata/system/batocera.conf" "/userdata/system/batocera.conf" 2>/dev/null || true
                chmod 644 "/userdata/system/batocera.conf" 2>/dev/null || true
                echo "[$(date +"%H:%M:%S")]: Restored factory batocera.conf" >> "$LOG_FILE"
            fi
        else
            # Use mode backup
            if [ -f "${backup_dir}/userdata_configs/batocera.conf" ]; then
                cp -a "${backup_dir}/userdata_configs/batocera.conf" "/userdata/system/batocera.conf" 2>/dev/null || true
                chmod 644 "/userdata/system/batocera.conf" 2>/dev/null || true
                echo "[$(date +"%H:%M:%S")]: Restored batocera.conf from HD Mode backup" >> "$LOG_FILE"
            fi
        fi
        
        # Re-apply VNC settings if they existed (preserve across mode switches)
        if [ -f "$vnc_temp_file" ] && [ -s "$vnc_temp_file" ] && [ -f "/userdata/system/batocera.conf" ]; then
            while IFS= read -r vnc_line || [ -n "$vnc_line" ]; do
                if [ -n "$vnc_line" ]; then
                    vnc_key=$(echo "$vnc_line" | cut -d'=' -f1)
                    # Escape special characters for sed
                    vnc_key_escaped=$(printf '%s\n' "$vnc_key" | sed 's/[[\.*^$()+?{|]/\\&/g')
                    if grep -q "^${vnc_key}=" /userdata/system/batocera.conf 2>/dev/null; then
                        sed -i "s|^${vnc_key_escaped}=.*|${vnc_line}|" /userdata/system/batocera.conf 2>/dev/null || true
                    else
                        echo "$vnc_line" >> /userdata/system/batocera.conf 2>/dev/null || true
                    fi
                fi
            done < "$vnc_temp_file"
            rm -f "$vnc_temp_file" 2>/dev/null || true
            echo "[$(date +"%H:%M:%S")]: Preserved VNC settings in batocera.conf" >> "$LOG_FILE"
        else
            rm -f "$vnc_temp_file" 2>/dev/null || true
        fi
        
        # Ensure VNC command is available in HD mode (it's in overlay in CRT mode, so we need to create it in HD mode)
        # Note: /usr/bin/ is in overlay, so we'll create it via boot-custom.sh on boot for persistence
        # Create modified VNC script that uses full path to x11vnc from userdata (works even if x11vnc not in PATH)
        if [ -f "/boot/crt_theme_assets/vnc" ]; then
            # Copy from /boot (modified script with full paths)
            if cp -a "/boot/crt_theme_assets/vnc" "/usr/bin/vnc" 2>/dev/null; then
                chmod 755 "/usr/bin/vnc" 2>/dev/null || true
                echo "[$(date +"%H:%M:%S")]: Ensured VNC command is available in HD mode (/usr/bin/vnc)" >> "$LOG_FILE"
            fi
        elif [ -f "/userdata/system/Batocera-CRT-Script/install-vnc_server_batocera/vnc" ]; then
            # Ensure x11vnc has execute permissions
            chmod 755 /userdata/system/Batocera-CRT-Script/install-vnc_server_batocera/x11vnc 2>/dev/null || true
            # Fallback: create modified script directly
            cat > /usr/bin/vnc << 'VNC_SCRIPT_EOF'
#!/bin/bash

export DISPLAY=:0

# Set LD_LIBRARY_PATH for VNC libraries (userdata location)
export LD_LIBRARY_PATH="/userdata/system/Batocera-CRT-Script/install-vnc_server_batocera:${LD_LIBRARY_PATH}"

# Kill any existing x11vnc instances using port 5900 (optional but safer)
fuser -k 5900/tcp 2>/dev/null || true

# Start x11vnc on port 5900 (use full path from userdata)
/userdata/system/Batocera-CRT-Script/install-vnc_server_batocera/x11vnc -forever -noxdamage -rfbport 5900 -shared
VNC_SCRIPT_EOF
            chmod 755 /usr/bin/vnc 2>/dev/null || true
            echo "[$(date +"%H:%M:%S")]: Created VNC script in HD mode with full paths (/usr/bin/vnc)" >> "$LOG_FILE"
        fi
        
        # Remove CRT-only files
        rm -f "/userdata/system/videomodes.conf" 2>/dev/null || true
        rm -f "/userdata/system/videomodes.conf.bak" 2>/dev/null || true
        rm -f "/userdata/system/es.arg.override" 2>/dev/null || true
        rm -f "/userdata/system/99-nvidia.conf" 2>/dev/null || true
        echo "[$(date +"%H:%M:%S")]: Removed CRT-only userdata files" >> "$LOG_FILE"
        
        # Remove old boot-custom.sh and crt_theme_assets (single-boot only)
        # Dual-boot: skip removal — boot-custom.sh is recreated below for theme asset persistence
        if ! is_dualboot_system; then
            if mount -o remount,rw /boot 2>/dev/null; then
                if [ -f "/boot/boot-custom.sh" ]; then
                    rm -f "/boot/boot-custom.sh" 2>/dev/null || true
                    echo "[$(date +"%H:%M:%S")]: Removed old /boot/boot-custom.sh (CRT-only)" >> "$LOG_FILE"
                fi
                rm -rf "/boot/crt_theme_assets" 2>/dev/null || true
                mount -o remount,ro /boot 2>/dev/null || true
            else
                echo "[$(date +"%H:%M:%S")]: ERROR: Failed to remount /boot as writable" >> "$LOG_FILE"
            fi
        fi
        
        # Create HD mode boot-custom.sh (copies CRT theme assets from /boot to /usr/share/ on boot)
        # Runs via /etc/init.d/S00bootcustom before EmulationStation starts
        if is_dualboot_system; then
            # Dual-boot: create a unified boot-custom.sh that auto-detects the boot mode.
            # In HD/Wayland mode: copies CRT theme assets to /usr/share/ (volatile).
            # In CRT/X11 mode: generates /etc/X11/xorg.conf.d/15-crt-monitor.conf
            #   (HorizSync/VertRefresh from EDID, DefaultModes=False) before X starts.
            # Detection: kernel cmdline contains BOOT_IMAGE=/crt/ when in CRT mode.
            if mount -o remount,rw /boot 2>/dev/null; then
                mkdir -p /boot/crt_theme_assets 2>/dev/null || true
                [ -f "/userdata/system/Batocera-CRT-Script/Geometry_modeline/CRT.png" ] && \
                    cp /userdata/system/Batocera-CRT-Script/Geometry_modeline/CRT.png /boot/crt_theme_assets/CRT.png 2>/dev/null || true
                [ -f "/userdata/system/Batocera-CRT-Script/Geometry_modeline/CRT.svg" ] && \
                    cp /userdata/system/Batocera-CRT-Script/Geometry_modeline/CRT.svg /boot/crt_theme_assets/CRT.svg 2>/dev/null || true

                if [ -f "/userdata/system/Batocera-CRT-Script/install-vnc_server_batocera/x11vnc" ]; then
                    chmod 755 /userdata/system/Batocera-CRT-Script/install-vnc_server_batocera/x11vnc 2>/dev/null || true
                    cat > /boot/crt_theme_assets/vnc << 'VNC_DUALBOOT_EOF'
#!/bin/bash
export DISPLAY=:0
export LD_LIBRARY_PATH="/userdata/system/Batocera-CRT-Script/install-vnc_server_batocera:${LD_LIBRARY_PATH}"
fuser -k 5900/tcp 2>/dev/null || true
/userdata/system/Batocera-CRT-Script/install-vnc_server_batocera/x11vnc -forever -noxdamage -rfbport 5900 -shared
VNC_DUALBOOT_EOF
                    chmod 755 /boot/crt_theme_assets/vnc 2>/dev/null || true
                fi

                cat > /boot/boot-custom.sh << 'BOOTCUSTOM_DUALBOOT_EOF'
#!/bin/bash
# Dual-boot boot-custom.sh — auto-detects HD (Wayland) vs CRT (X11) mode
# Runs via /etc/init.d/S00bootcustom very early in boot (before X/Wayland)

copy_theme_assets() {
  mkdir -p /usr/share/emulationstation/themes/es-theme-carbon/art/consoles 2>/dev/null || true
  mkdir -p /usr/share/emulationstation/themes/es-theme-carbon/art/logos 2>/dev/null || true
  [ -f "/boot/crt_theme_assets/CRT.png" ] && \
    cp /boot/crt_theme_assets/CRT.png /usr/share/emulationstation/themes/es-theme-carbon/art/consoles/CRT.png 2>/dev/null && \
    chmod 644 /usr/share/emulationstation/themes/es-theme-carbon/art/consoles/CRT.png 2>/dev/null || true
  [ -f "/boot/crt_theme_assets/CRT.svg" ] && \
    cp /boot/crt_theme_assets/CRT.svg /usr/share/emulationstation/themes/es-theme-carbon/art/logos/CRT.svg 2>/dev/null && \
    chmod 644 /usr/share/emulationstation/themes/es-theme-carbon/art/logos/CRT.svg 2>/dev/null || true
}

generate_crt_xorg_conf() {
  local CONF="/etc/X11/xorg.conf.d/15-crt-monitor.conf"
  local MON10="/etc/X11/xorg.conf.d/10-monitor.conf"

  local OUT=""
  if [ -f "$MON10" ]; then
    OUT="$(awk '
      BEGIN{s=0;id="";ign=0}
      /^[[:space:]]*Section[[:space:]]+"Monitor"/ {s=1;id="";ign=0;next}
      s && /^[[:space:]]*Identifier[[:space:]]+"/ {
        match($0,/Identifier[[:space:]]*"[^\"]+"/)
        if (RSTART) { id=substr($0,RSTART+length("Identifier \""),
                  RLENGTH-length("Identifier \"")-1) }
      }
      s && /Option[[:space:]]+"Ignore"[[:space:]]+"true"/ { ign=1 }
      s && /^[[:space:]]*EndSection/ { if (id!="" && ign==0) { print id; exit } s=0 }
    ' "$MON10")"
  fi
  if [ -z "$OUT" ]; then
    for d in /sys/class/drm/card*-*; do
      [ -e "$d/status" ] || continue
      if [ "$(cat "$d/status" 2>/dev/null)" = "connected" ]; then
        OUT="${d##*/}"; OUT="${OUT#card[0-9]-}"
        break
      fi
    done
  fi
  [ -z "$OUT" ] && return 0

  local CMD="$(cat /proc/cmdline 2>/dev/null)"
  local EDID_FILE_CMD="$(printf '%s\n' "$CMD" | sed -n 's/.*drm\.edid_firmware=[^ :]\+:edid\/\([^ ]\+\).*/\1/p' | head -n1)"
  local EDID_BIN="" EDID_SRC=""

  if [ -f "/lib/firmware/edid/custom.bin" ]; then
    EDID_BIN="/lib/firmware/edid/custom.bin"; EDID_SRC="custom.bin"
  elif [ -n "$EDID_FILE_CMD" ] && [ -f "/lib/firmware/edid/$EDID_FILE_CMD" ]; then
    EDID_BIN="/lib/firmware/edid/$EDID_FILE_CMD"; EDID_SRC="$EDID_FILE_CMD"
  else
    EDID_BIN="$(ls /lib/firmware/edid/*.bin 2>/dev/null | head -n1)"
    EDID_SRC="$(basename "$EDID_BIN" 2>/dev/null)"
  fi

  local VR="" HR=""
  if [ -n "$EDID_BIN" ] && [ -f "$EDID_BIN" ]; then
    local LINE="$(edid-decode "$EDID_BIN" 2>/dev/null | grep -m1 'Display Range Limits' || true)"
    VR="$(printf '%s\n' "$LINE" | sed -n 's/.* \([0-9][0-9]*\)-\([0-9][0-9]*\) Hz V.*/\1-\2/p')"
    HR="$(printf '%s\n' "$LINE" | sed -n 's/.* \([0-9][0-9]*\(\.[0-9]\)\?\)-\([0-9][0-9]*\(\.[0-9]\)\?\) kHz H.*/\1-\3/p')"
  fi
  [ -n "$VR" ] || VR="49-65"
  [ -n "$HR" ] || HR="15-16.5"

  mkdir -p /etc/X11/xorg.conf.d
  cat > "$CONF" <<XEOF
Section "Monitor"
    Identifier  "CRT"
    VendorName  "BATOCERA_CRT_SCRIPT"
    HorizSync   $HR
    VertRefresh $VR
    Option      "DPMS" "False"
    Option      "DefaultModes" "False"
EndSection

Section "Device"
    Identifier "modesetting-amd-crt-bind"
    Driver "modesetting"
    Option "Monitor-$OUT" "CRT"
EndSection
XEOF
}

install_vnc() {
  [ -f "/boot/crt_theme_assets/vnc" ] || return 0
  cp /boot/crt_theme_assets/vnc /usr/bin/vnc 2>/dev/null && chmod 755 /usr/bin/vnc 2>/dev/null || true
}

main() {
  [ "$1" = "start" ] || return 0

  local CMD="$(cat /proc/cmdline 2>/dev/null)"
  if echo "$CMD" | grep -q 'BOOT_IMAGE=/crt/'; then
    generate_crt_xorg_conf
    copy_theme_assets
    install_vnc
  else
    copy_theme_assets
  fi
}

main "$@"
BOOTCUSTOM_DUALBOOT_EOF
                chmod 755 /boot/boot-custom.sh 2>/dev/null || true
                mount -o remount,ro /boot 2>/dev/null || true
                echo "[$(date +"%H:%M:%S")]: Dual-boot: created unified boot-custom.sh (mode-aware: HD=theme-assets, CRT=xorg-conf+vnc)" >> "$LOG_FILE"
            else
                echo "[$(date +"%H:%M:%S")]: ERROR: Failed to remount /boot as writable (cannot create boot-custom.sh)" >> "$LOG_FILE"
            fi
        elif mount -o remount,rw /boot 2>/dev/null; then
            # Copy theme assets to /boot (persistent, always available on boot)
            mkdir -p /boot/crt_theme_assets 2>/dev/null || true
            if [ -f "/userdata/system/Batocera-CRT-Script/Geometry_modeline/CRT.png" ]; then
                cp /userdata/system/Batocera-CRT-Script/Geometry_modeline/CRT.png /boot/crt_theme_assets/CRT.png 2>/dev/null || true
            fi
            if [ -f "/userdata/system/Batocera-CRT-Script/Geometry_modeline/CRT.svg" ]; then
                cp /userdata/system/Batocera-CRT-Script/Geometry_modeline/CRT.svg /boot/crt_theme_assets/CRT.svg 2>/dev/null || true
            fi
            # Copy VNC script to /boot (script file is in /boot, but script content uses /userdata paths at runtime)
            # Create modified VNC script that uses full path to x11vnc from userdata
            if [ -f "/userdata/system/Batocera-CRT-Script/install-vnc_server_batocera/vnc" ]; then
                # Ensure x11vnc has execute permissions
                chmod 755 /userdata/system/Batocera-CRT-Script/install-vnc_server_batocera/x11vnc 2>/dev/null || true
                # Create modified VNC script that uses full path to x11vnc (script file in /boot, content references /userdata)
                cat > /boot/crt_theme_assets/vnc << 'VNC_SCRIPT_EOF'
#!/bin/bash

export DISPLAY=:0

# Set LD_LIBRARY_PATH for VNC libraries (userdata location)
export LD_LIBRARY_PATH="/userdata/system/Batocera-CRT-Script/install-vnc_server_batocera:${LD_LIBRARY_PATH}"

# Kill any existing x11vnc instances using port 5900 (optional but safer)
fuser -k 5900/tcp 2>/dev/null || true

# Start x11vnc on port 5900 (use full path from userdata)
/userdata/system/Batocera-CRT-Script/install-vnc_server_batocera/x11vnc -forever -noxdamage -rfbport 5900 -shared
VNC_SCRIPT_EOF
                chmod 755 /boot/crt_theme_assets/vnc 2>/dev/null || true
            fi
            
            # Create boot-custom.sh that copies from /boot to /usr/share/ (no /userdata dependency)
            cat > /boot/boot-custom.sh << 'BOOTCUSTOM_EOF'
#!/bin/bash
# HD Mode: Copy CRT theme assets from /boot to /usr/share/ on boot
# Runs via /etc/init.d/S00bootcustom very early in boot (before EmulationStation)
# Files are pre-copied to /boot during mode switch, so /userdata mount timing doesn't matter

main() {
  # Run only on start
  [ "$1" = "start" ] || return 0
  
  # Only copy in HD mode (check if overlay exists - if not, we're in HD mode)
  if [ ! -f "/boot/boot/overlay" ]; then
    # Ensure directories exist
    mkdir -p /usr/share/emulationstation/themes/es-theme-carbon/art/consoles 2>/dev/null || true
    mkdir -p /usr/share/emulationstation/themes/es-theme-carbon/art/logos 2>/dev/null || true
    
    # Copy CRT.png from /boot (always available, no /userdata dependency)
    if [ -f "/boot/crt_theme_assets/CRT.png" ]; then
      cp /boot/crt_theme_assets/CRT.png /usr/share/emulationstation/themes/es-theme-carbon/art/consoles/CRT.png 2>/dev/null && \
      chmod 644 /usr/share/emulationstation/themes/es-theme-carbon/art/consoles/CRT.png 2>/dev/null || true
    fi
    
    # Copy CRT.svg from /boot (always available, no /userdata dependency)
    if [ -f "/boot/crt_theme_assets/CRT.svg" ]; then
      cp /boot/crt_theme_assets/CRT.svg /usr/share/emulationstation/themes/es-theme-carbon/art/logos/CRT.svg 2>/dev/null && \
      chmod 644 /usr/share/emulationstation/themes/es-theme-carbon/art/logos/CRT.svg 2>/dev/null || true
    fi
    
    # Ensure VNC command is available in HD mode (it's in overlay in CRT mode)
    # Copy from /boot (script file available early, script content uses /userdata paths at runtime) - retry if overlay not ready
    if [ -f "/boot/crt_theme_assets/vnc" ]; then
      # Try to copy to /usr/bin/vnc (retry if overlay not ready)
      vnc_created=false
      for i in 1 2 3 4 5; do
        if cp /boot/crt_theme_assets/vnc /usr/bin/vnc 2>/dev/null && \
           chmod 755 /usr/bin/vnc 2>/dev/null; then
          vnc_created=true
          break
        fi
        sleep 1
      done
      # Ensure x11vnc has execute permissions (if /userdata is available)
      if [ -f "/userdata/system/Batocera-CRT-Script/install-vnc_server_batocera/x11vnc" ]; then
        chmod 755 /userdata/system/Batocera-CRT-Script/install-vnc_server_batocera/x11vnc 2>/dev/null || true
      fi
      # Fallback: create modified script from /userdata if /boot copy failed and /userdata is available
      if [ "$vnc_created" = false ] && [ -f "/userdata/system/Batocera-CRT-Script/install-vnc_server_batocera/x11vnc" ]; then
        cat > /usr/bin/vnc << 'VNC_SCRIPT_EOF'
#!/bin/bash

export DISPLAY=:0

# Set LD_LIBRARY_PATH for VNC libraries (userdata location)
export LD_LIBRARY_PATH="/userdata/system/Batocera-CRT-Script/install-vnc_server_batocera:${LD_LIBRARY_PATH}"

# Kill any existing x11vnc instances using port 5900 (optional but safer)
fuser -k 5900/tcp 2>/dev/null || true

# Start x11vnc on port 5900 (use full path from userdata)
/userdata/system/Batocera-CRT-Script/install-vnc_server_batocera/x11vnc -forever -noxdamage -rfbport 5900 -shared
VNC_SCRIPT_EOF
        chmod 755 /usr/bin/vnc 2>/dev/null || true
        vnc_created=true
      fi
      # Final fallback: create symlink if both methods failed
      if [ "$vnc_created" = false ] && [ ! -L /usr/bin/vnc ]; then
        if [ -f "/boot/crt_theme_assets/vnc" ]; then
          ln -sf /boot/crt_theme_assets/vnc /usr/bin/vnc 2>/dev/null || true
        elif [ -f "/userdata/system/Batocera-CRT-Script/install-vnc_server_batocera/vnc" ]; then
          ln -sf /userdata/system/Batocera-CRT-Script/install-vnc_server_batocera/vnc /usr/bin/vnc 2>/dev/null || true
        fi
      fi
    fi
  fi
}

main "$@"
BOOTCUSTOM_EOF
            chmod 755 /boot/boot-custom.sh 2>/dev/null || true
            mount -o remount,ro /boot 2>/dev/null || true
            echo "[$(date +"%H:%M:%S")]: Created HD mode boot-custom.sh (copies CRT theme assets on boot)" >> "$LOG_FILE"
        else
            echo "[$(date +"%H:%M:%S")]: ERROR: Failed to remount /boot as writable (cannot create boot-custom.sh)" >> "$LOG_FILE"
        fi
        
        # Remove CRT-specific X11 config generated by boot-custom.sh
        if [ -f "/etc/X11/xorg.conf.d/15-crt-monitor.conf" ]; then
            rm -f "/etc/X11/xorg.conf.d/15-crt-monitor.conf" 2>/dev/null || true
            echo "[$(date +"%H:%M:%S")]: Removed 15-crt-monitor.conf (CRT-only)" >> "$LOG_FILE"
        fi
        
        # 3. RESTORE/MOVE ENTIRE FOLDERS
        
        # Scripts folder (HD Mode: Remove only CRT Script files, preserve user custom scripts)
        remove_crt_script_files_only
        
        if [ -d "${backup_dir}/userdata_configs/scripts" ]; then
            # Restore any HD mode scripts from backup (preserves user custom scripts)
            restore_crt_script_files "${backup_dir}/userdata_configs/scripts"
            echo "[$(date +"%H:%M:%S")]: Restored scripts from HD Mode backup (preserved user custom scripts)" >> "$LOG_FILE"
        else
            echo "[$(date +"%H:%M:%S")]: No HD Mode scripts backup - removed CRT Script files only (preserved user custom scripts)" >> "$LOG_FILE"
        fi
        
        # Note: CRT theme assets are copied via boot-custom.sh (created above) which runs early in boot
        
        # MAME folder
        if [ -d "${backup_dir}/emulator_configs/mame" ]; then
            rm -rf "/userdata/system/configs/mame" 2>/dev/null || true
            mkdir -p "/userdata/system/configs"
            cp -ra "${backup_dir}/emulator_configs/mame" "/userdata/system/configs/mame" 2>/dev/null || true
            echo "[$(date +"%H:%M:%S")]: Restored entire mame/ folder from HD Mode backup" >> "$LOG_FILE"
        else
            rm -rf "/userdata/system/configs/mame" 2>/dev/null || true
            echo "[$(date +"%H:%M:%S")]: No mame/ folder in HD Mode backup, removed CRT mame configs" >> "$LOG_FILE"
        fi
        
        # RetroArch folder
        if [ -d "${backup_dir}/emulator_configs/retroarch" ]; then
            rm -rf "/userdata/system/configs/retroarch" 2>/dev/null || true
            mkdir -p "/userdata/system/configs"
            cp -ra "${backup_dir}/emulator_configs/retroarch" "/userdata/system/configs/retroarch" 2>/dev/null || true
            echo "[$(date +"%H:%M:%S")]: Restored entire retroarch/ folder from HD Mode backup" >> "$LOG_FILE"
        else
            rm -rf "/userdata/system/configs/retroarch" 2>/dev/null || true
            echo "[$(date +"%H:%M:%S")]: No retroarch/ folder in HD Mode backup, removed CRT retroarch configs" >> "$LOG_FILE"
        fi
        
        # EmulationStation es_settings.cfg (AMD R9 instant transitions workaround)
        if [ -f "${backup_dir}/emulator_configs/emulationstation/es_settings.cfg" ]; then
            mkdir -p "/userdata/system/configs/emulationstation"
            cp -a "${backup_dir}/emulator_configs/emulationstation/es_settings.cfg" "/userdata/system/configs/emulationstation/es_settings.cfg" 2>/dev/null || true
            echo "[$(date +"%H:%M:%S")]: Restored es_settings.cfg from HD Mode backup" >> "$LOG_FILE"
        else
            echo "[$(date +"%H:%M:%S")]: No es_settings.cfg in HD Mode backup" >> "$LOG_FILE"
        fi
        
        # 4. DISABLE MULTISCREEN IN HD MODE
        # Dual-boot: skip — factory batocera.conf already has videooutput2=none
        # and explicit global.videooutput breaks Wayland display auto-detection
        if ! is_dualboot_system; then
            if [ -f "/userdata/system/batocera.conf" ]; then
                sed -i '/^global\.videooutput2=/d' /userdata/system/batocera.conf 2>/dev/null || true
                sed -i '/^global\.videooutput3=/d' /userdata/system/batocera.conf 2>/dev/null || true
                echo "global.videooutput2=none" >> /userdata/system/batocera.conf
                echo "[$(date +"%H:%M:%S")]: Disabled multiscreen for HD Mode" >> "$LOG_FILE"
            fi
        fi
        
    elif [ "$mode" = "crt" ]; then
        #########################################################################
        # CRT MODE RESTORE (Userdata-only approach)
        #########################################################################
        
        echo "[$(date +"%H:%M:%S")]: CRT Mode: Restoring CRT configuration" >> "$LOG_FILE"
        
        # 1. RESTORE USERDATA SYSTEM CONFIGS (Do this FIRST - needed for syslinux.cfg modification)
        # Preserve VNC settings from source mode's backup (they should persist across mode switches)
        local vnc_temp_file="/tmp/vnc_settings_$$.txt"
        # Try to extract VNC from source mode's backup first (most reliable)
        if [ -f "${source_backup_dir}/userdata_configs/batocera.conf" ]; then
            grep -E "^global\.vnc\." "${source_backup_dir}/userdata_configs/batocera.conf" > "$vnc_temp_file" 2>/dev/null || true
        fi
        # Fallback to current batocera.conf if source backup doesn't have VNC
        if [ ! -s "$vnc_temp_file" ] && [ -f "/userdata/system/batocera.conf" ]; then
            grep -E "^global\.vnc\." /userdata/system/batocera.conf > "$vnc_temp_file" 2>/dev/null || true
        fi
        
        if [ -f "${backup_dir}/userdata_configs/batocera.conf" ]; then
            cp -a "${backup_dir}/userdata_configs/batocera.conf" "/userdata/system/batocera.conf" 2>/dev/null || true
            chmod 644 "/userdata/system/batocera.conf" 2>/dev/null || true
            echo "[$(date +"%H:%M:%S")]: Restored batocera.conf from CRT Mode backup" >> "$LOG_FILE"
        fi
        
        # Re-apply VNC settings if they existed (preserve across mode switches)
        if [ -f "$vnc_temp_file" ] && [ -s "$vnc_temp_file" ] && [ -f "/userdata/system/batocera.conf" ]; then
            while IFS= read -r vnc_line || [ -n "$vnc_line" ]; do
                if [ -n "$vnc_line" ]; then
                    vnc_key=$(echo "$vnc_line" | cut -d'=' -f1)
                    # Escape special characters for sed
                    vnc_key_escaped=$(printf '%s\n' "$vnc_key" | sed 's/[[\.*^$()+?{|]/\\&/g')
                    if grep -q "^${vnc_key}=" /userdata/system/batocera.conf 2>/dev/null; then
                        sed -i "s|^${vnc_key_escaped}=.*|${vnc_line}|" /userdata/system/batocera.conf 2>/dev/null || true
                    else
                        echo "$vnc_line" >> /userdata/system/batocera.conf 2>/dev/null || true
                    fi
                fi
            done < "$vnc_temp_file"
            rm -f "$vnc_temp_file" 2>/dev/null || true
            echo "[$(date +"%H:%M:%S")]: Preserved VNC settings in batocera.conf" >> "$LOG_FILE"
        else
            rm -f "$vnc_temp_file" 2>/dev/null || true
        fi
        
        # Ensure VNC command is available in CRT mode (should be in overlay, but ensure it exists)
        # In CRT mode, overlay contains /usr/bin/vnc and /usr/bin/x11vnc, so original script works (x11vnc in PATH)
        # Also ensure x11vnc binary has execute permissions
        if [ -f "/userdata/system/Batocera-CRT-Script/install-vnc_server_batocera/vnc" ]; then
            chmod 755 /userdata/system/Batocera-CRT-Script/install-vnc_server_batocera/x11vnc 2>/dev/null || true
            cp -a "/userdata/system/Batocera-CRT-Script/install-vnc_server_batocera/vnc" "/usr/bin/vnc" 2>/dev/null || true
            chmod 755 "/usr/bin/vnc" 2>/dev/null || true
            echo "[$(date +"%H:%M:%S")]: Ensured VNC command is available in CRT mode (/usr/bin/vnc)" >> "$LOG_FILE"
        fi
        
        # Restore CRT-specific files
        if [ -f "${backup_dir}/userdata_configs/videomodes.conf" ]; then
            cp -a "${backup_dir}/userdata_configs/videomodes.conf" "/userdata/system/videomodes.conf" 2>/dev/null || true
            chmod 644 "/userdata/system/videomodes.conf" 2>/dev/null || true
            echo "[$(date +"%H:%M:%S")]: Restored videomodes.conf" >> "$LOG_FILE"
        fi
        
        if [ -f "${backup_dir}/userdata_configs/es.arg.override" ]; then
            cp -a "${backup_dir}/userdata_configs/es.arg.override" "/userdata/system/es.arg.override" 2>/dev/null || true
            chmod 644 "/userdata/system/es.arg.override" 2>/dev/null || true
            echo "[$(date +"%H:%M:%S")]: Restored es.arg.override" >> "$LOG_FILE"
        fi
        
        if [ -f "${backup_dir}/userdata_configs/99-nvidia.conf" ]; then
            cp -a "${backup_dir}/userdata_configs/99-nvidia.conf" "/userdata/system/99-nvidia.conf" 2>/dev/null || true
            chmod 644 "/userdata/system/99-nvidia.conf" 2>/dev/null || true
            echo "[$(date +"%H:%M:%S")]: Restored 99-nvidia.conf" >> "$LOG_FILE"
        fi
        
        # 2. RESTORE/MOVE ENTIRE FOLDERS
        
        # Scripts folder (CRT Mode: Remove only CRT Script files, restore from backup, preserve user custom scripts)
        remove_crt_script_files_only
        
        # Remove CRT theme assets from userdata override (not needed in CRT mode - overlay contains files)
        rm -f /userdata/themes/es-theme-carbon/art/consoles/CRT.png 2>/dev/null || true
        rm -f /userdata/themes/es-theme-carbon/art/logos/CRT.svg 2>/dev/null || true
        echo "[$(date +"%H:%M:%S")]: Removed CRT theme assets from userdata override (CRT mode uses overlay)" >> "$LOG_FILE"
        
        if [ -d "${backup_dir}/userdata_configs/scripts" ]; then
            restore_crt_script_files "${backup_dir}/userdata_configs/scripts"
            echo "[$(date +"%H:%M:%S")]: Restored CRT Script files from CRT Mode backup (preserved user custom scripts)" >> "$LOG_FILE"
        else
            echo "[$(date +"%H:%M:%S")]: No scripts/ folder in CRT Mode backup" >> "$LOG_FILE"
        fi
        
        # Remove CRT theme assets and VNC script from /boot (not needed in CRT mode - overlay contains files)
        # Dual-boot: skip — /boot is shared, don't remove assets Wayland may need
        if ! is_dualboot_system; then
            if mount -o remount,rw /boot 2>/dev/null; then
                rm -rf "/boot/crt_theme_assets" 2>/dev/null || true
                mount -o remount,ro /boot 2>/dev/null || true
                echo "[$(date +"%H:%M:%S")]: Removed CRT theme assets and VNC script from /boot (CRT mode uses overlay)" >> "$LOG_FILE"
            fi
        fi
        
        # MAME folder
        if [ -d "${backup_dir}/emulator_configs/mame" ]; then
            rm -rf "/userdata/system/configs/mame" 2>/dev/null || true
            mkdir -p "/userdata/system/configs"
            cp -ra "${backup_dir}/emulator_configs/mame" "/userdata/system/configs/mame" 2>/dev/null || true
            echo "[$(date +"%H:%M:%S")]: Restored entire mame/ folder from CRT Mode backup" >> "$LOG_FILE"
        else
            echo "[$(date +"%H:%M:%S")]: No mame/ folder in CRT Mode backup" >> "$LOG_FILE"
        fi
        
        # RetroArch folder
        if [ -d "${backup_dir}/emulator_configs/retroarch" ]; then
            rm -rf "/userdata/system/configs/retroarch" 2>/dev/null || true
            mkdir -p "/userdata/system/configs"
            cp -ra "${backup_dir}/emulator_configs/retroarch" "/userdata/system/configs/retroarch" 2>/dev/null || true
            echo "[$(date +"%H:%M:%S")]: Restored entire retroarch/ folder from CRT Mode backup" >> "$LOG_FILE"
        else
            echo "[$(date +"%H:%M:%S")]: No retroarch/ folder in CRT Mode backup" >> "$LOG_FILE"
        fi
        
        # EmulationStation es_settings.cfg (AMD R9 instant transitions workaround)
        if [ -f "${backup_dir}/emulator_configs/emulationstation/es_settings.cfg" ]; then
            mkdir -p "/userdata/system/configs/emulationstation"
            cp -a "${backup_dir}/emulator_configs/emulationstation/es_settings.cfg" "/userdata/system/configs/emulationstation/es_settings.cfg" 2>/dev/null || true
            echo "[$(date +"%H:%M:%S")]: Restored es_settings.cfg from CRT Mode backup" >> "$LOG_FILE"
        else
            echo "[$(date +"%H:%M:%S")]: No es_settings.cfg in CRT Mode backup" >> "$LOG_FILE"
        fi
        
        # 3. RESTORE BOOT-CUSTOM.SH (Creates X11 configs on boot)
        if ! is_dualboot_system; then
            if [ -f "${backup_dir}/boot_configs/boot-custom.sh" ]; then
                cp -a "${backup_dir}/boot_configs/boot-custom.sh" "/boot/boot-custom.sh" 2>/dev/null || true
                chmod 755 "/boot/boot-custom.sh" 2>/dev/null || true
                echo "[$(date +"%H:%M:%S")]: Restored boot-custom.sh" >> "$LOG_FILE"
            fi
        fi
        
        # 4. RESTORE SYSLINUX.CFG (CRT kernel parameters for EDID override)
        if is_dualboot_system; then
            # Dual-boot: just flip DEFAULT to crt (preserves dual-boot structure)
            set_syslinux_boot_default "crt"
        else
            # Single-boot: restore entire syslinux.cfg from backup
            if [ -f "${backup_dir}/boot_configs/boot/syslinux.cfg" ]; then
                mkdir -p "/boot/boot"
                cp -a "${backup_dir}/boot_configs/boot/syslinux.cfg" "/boot/boot/syslinux.cfg" 2>/dev/null || true
                chmod 644 "/boot/boot/syslinux.cfg" 2>/dev/null || true
                echo "[$(date +"%H:%M:%S")]: Restored syslinux.cfg from CRT Mode backup (with EDID params)" >> "$LOG_FILE"
            fi
            for syslinux_path in "EFI/batocera/syslinux.cfg" "EFI/BOOT/syslinux.cfg"; do
                if [ -f "${backup_dir}/boot_configs/${syslinux_path}" ]; then
                    mkdir -p "/boot/$(dirname "$syslinux_path")"
                    cp -a "${backup_dir}/boot_configs/${syslinux_path}" "/boot/${syslinux_path}" 2>/dev/null || true
                    chmod 644 "/boot/${syslinux_path}" 2>/dev/null || true
                    echo "[$(date +"%H:%M:%S")]: Restored ${syslinux_path} from CRT Mode backup" >> "$LOG_FILE"
                fi
            done
        fi
        
        
    fi
    
    #############################################################################
    # RESTORE VIDEO SETTINGS (Common to both modes)
    # The overlay contamination that originally broke Wayland's display-checker
    # when global.videooutput was set explicitly has been fixed (CRT overlay is
    # now isolated to /boot/crt/overlay, factory batocera-resolution uses
    # wlr-randr and correctly lists eDP-1).
    #############################################################################
    
    restore_video_settings "$mode"
    
    if is_dualboot_system && [ "$mode" = "hd" ]; then
        if [ -f "/userdata/system/batocera.conf" ]; then
            sed -i '/^display\.rotate=0$/d' /userdata/system/batocera.conf 2>/dev/null || true
        fi
    fi
    
    #############################################################################
    # REINSTALL CRT TOOLS (Ensure visibility matches mode)
    #############################################################################
    
    echo "[$(date +"%H:%M:%S")]: Reinstalling CRT Tools for $mode mode..." >> "$LOG_FILE"
    
    # Step 1: Create CRT Tools directory
    mkdir -p "$CRT_ROMS/crt" 2>/dev/null || true
    
    # Step 2: Copy CRT Tools based on mode
    if [ "$mode" = "hd" ]; then
        # HD Mode: Clean up CRT Tools directory first, then only install Mode Selector
        echo "[$(date +"%H:%M:%S")]: HD Mode: Installing Mode Selector only" >> "$LOG_FILE"
        rm -rf "$CRT_ROMS/crt/"* 2>/dev/null || true
        mkdir -p "$CRT_ROMS/crt/images" 2>/dev/null || true
        
        if [ -f "/userdata/system/Batocera-CRT-Script/Geometry_modeline/crt/mode_switcher.sh" ]; then
            cp /userdata/system/Batocera-CRT-Script/Geometry_modeline/crt/mode_switcher.sh "$CRT_ROMS/crt/mode_switcher.sh" 2>/dev/null || true
            chmod 755 "$CRT_ROMS/crt/mode_switcher.sh" 2>/dev/null || true
        fi
        if [ -f "/userdata/system/Batocera-CRT-Script/Geometry_modeline/crt/mode_switcher.sh.keys" ]; then
            cp /userdata/system/Batocera-CRT-Script/Geometry_modeline/crt/mode_switcher.sh.keys "$CRT_ROMS/crt/mode_switcher.sh.keys" 2>/dev/null || true
            chmod 644 "$CRT_ROMS/crt/mode_switcher.sh.keys" 2>/dev/null || true
        fi
        # Copy Mode Selector images (image, logo, thumb)
        if [ -d "/userdata/system/Batocera-CRT-Script/Geometry_modeline/crt/images" ]; then
            mkdir -p "$CRT_ROMS/crt/images" 2>/dev/null || true
            if [ -f "/userdata/system/Batocera-CRT-Script/Geometry_modeline/crt/images/hd_crt_switcher-image.png" ]; then
                cp /userdata/system/Batocera-CRT-Script/Geometry_modeline/crt/images/hd_crt_switcher-image.png "$CRT_ROMS/crt/images/" 2>/dev/null || true
            fi
            if [ -f "/userdata/system/Batocera-CRT-Script/Geometry_modeline/crt/images/hd_crt_switcher-logo.png" ]; then
                cp /userdata/system/Batocera-CRT-Script/Geometry_modeline/crt/images/hd_crt_switcher-logo.png "$CRT_ROMS/crt/images/" 2>/dev/null || true
            fi
            if [ -f "/userdata/system/Batocera-CRT-Script/Geometry_modeline/crt/images/hd_crt_switcher-thumb.png" ]; then
                cp /userdata/system/Batocera-CRT-Script/Geometry_modeline/crt/images/hd_crt_switcher-thumb.png "$CRT_ROMS/crt/images/" 2>/dev/null || true
            fi
        fi
        # Copy gamelist.xml
        if [ -f "/userdata/system/Batocera-CRT-Script/Geometry_modeline/crt/gamelist.xml" ]; then
            cp /userdata/system/Batocera-CRT-Script/Geometry_modeline/crt/gamelist.xml "$CRT_ROMS/crt/gamelist.xml" 2>/dev/null || true
            chmod 644 "$CRT_ROMS/crt/gamelist.xml" 2>/dev/null || true
        fi
        # Copy CRT.svg and CRT.png (needed for EmulationStation system icon)
        if [ -f "/userdata/system/Batocera-CRT-Script/Geometry_modeline/CRT.svg" ]; then
            cp /userdata/system/Batocera-CRT-Script/Geometry_modeline/CRT.svg "$CRT_ROMS/crt/CRT.svg" 2>/dev/null || true
            chmod 644 "$CRT_ROMS/crt/CRT.svg" 2>/dev/null || true
        fi
        if [ -f "/userdata/system/Batocera-CRT-Script/Geometry_modeline/CRT.png" ]; then
            cp /userdata/system/Batocera-CRT-Script/Geometry_modeline/CRT.png "$CRT_ROMS/crt/CRT.png" 2>/dev/null || true
            chmod 644 "$CRT_ROMS/crt/CRT.png" 2>/dev/null || true
        fi
    else
        # CRT Mode: Install all CRT Tools
        echo "[$(date +"%H:%M:%S")]: CRT Mode: Installing all CRT Tools" >> "$LOG_FILE"
        rm -rf "$CRT_ROMS/crt/"* 2>/dev/null || true
        mkdir -p "$CRT_ROMS/crt" 2>/dev/null || true
        
        if [ -d "/userdata/system/Batocera-CRT-Script/Geometry_modeline/crt" ]; then
            cp -a /userdata/system/Batocera-CRT-Script/Geometry_modeline/crt/ "$CRT_ROMS/" 2>/dev/null || true
        fi
        
        # Restore or recreate GunCon2_Calibration.sh
        # Method 1: Try to restore from backup first
        if [ -f "${backup_dir}/userdata_configs/GunCon2_Calibration.sh" ]; then
            cp -a "${backup_dir}/userdata_configs/GunCon2_Calibration.sh" "$CRT_ROMS/crt/GunCon2_Calibration.sh" 2>/dev/null || true
            chmod 755 "$CRT_ROMS/crt/GunCon2_Calibration.sh" 2>/dev/null || true
            echo "[$(date +"%H:%M:%S")]: Restored GunCon2_Calibration.sh from CRT Mode backup" >> "$LOG_FILE"
        else
            # Method 2: Recreate from template (like installation script does)
            local video_output_xrandr=$(get_video_output_xrandr)
            if [ -n "$video_output_xrandr" ] && [ -f "/userdata/system/Batocera-CRT-Script/GunCon2/GunCon2_Calibration.sh-generic" ]; then
                sed -e "s/\[card_display\]/$video_output_xrandr/g" /userdata/system/Batocera-CRT-Script/GunCon2/GunCon2_Calibration.sh-generic > "$CRT_ROMS/crt/GunCon2_Calibration.sh" 2>/dev/null || true
                chmod 755 "$CRT_ROMS/crt/GunCon2_Calibration.sh" 2>/dev/null || true
                echo "[$(date +"%H:%M:%S")]: Recreated GunCon2_Calibration.sh from template with video output: $video_output_xrandr" >> "$LOG_FILE"
            else
                echo "[$(date +"%H:%M:%S")]: WARNING: Could not restore or recreate GunCon2_Calibration.sh (video output: ${video_output_xrandr:-not found}, template: $(test -f /userdata/system/Batocera-CRT-Script/GunCon2/GunCon2_Calibration.sh-generic && echo 'found' || echo 'missing'))" >> "$LOG_FILE"
            fi
        fi
    fi
    
    # Step 3: Copy es_systems_crt.cfg
    if [ -f "/userdata/system/Batocera-CRT-Script/Geometry_modeline/es_systems_crt.cfg" ]; then
        mkdir -p /userdata/system/configs/emulationstation 2>/dev/null || true
        cp /userdata/system/Batocera-CRT-Script/Geometry_modeline/es_systems_crt.cfg /userdata/system/configs/emulationstation/es_systems_crt.cfg 2>/dev/null || true
        chmod 644 /userdata/system/configs/emulationstation/es_systems_crt.cfg 2>/dev/null || true
        touch /userdata/system/configs/emulationstation/es_systems_crt.cfg 2>/dev/null || true
        sync 2>/dev/null || true
    fi
    
    # Step 4: Copy CRT theme assets (needed for EmulationStation top-level system artwork)
    # HD Mode: Copy to /userdata/themes/ for persistence (no overlay = files must be in userdata)
    # CRT Mode: Skip copying (overlay already contains files in /usr/share/)
    if [ "$mode" = "hd" ]; then
        echo "[$(date +"%H:%M:%S")]: HD Mode: Copying CRT theme assets to userdata override (required for persistence)" >> "$LOG_FILE"
        
        # Ensure theme directories exist in userdata override location
        mkdir -p /userdata/themes/es-theme-carbon/art/consoles 2>/dev/null || true
        mkdir -p /userdata/themes/es-theme-carbon/art/logos 2>/dev/null || true
        # Set directory permissions so EmulationStation can read them (0755 = drwxr-xr-x)
        chmod 755 /userdata/themes/es-theme-carbon/art/consoles 2>/dev/null || true
        chmod 755 /userdata/themes/es-theme-carbon/art/logos 2>/dev/null || true
        chmod 755 /userdata/themes/es-theme-carbon/art 2>/dev/null || true
        chmod 755 /userdata/themes/es-theme-carbon 2>/dev/null || true
        
        # Copy CRT.png
        if [ -f "/userdata/system/Batocera-CRT-Script/Geometry_modeline/CRT.png" ]; then
            if cp /userdata/system/Batocera-CRT-Script/Geometry_modeline/CRT.png /userdata/themes/es-theme-carbon/art/consoles/CRT.png 2>>"$LOG_FILE"; then
                chmod 644 /userdata/themes/es-theme-carbon/art/consoles/CRT.png 2>/dev/null || true
                echo "[$(date +"%H:%M:%S")]: Successfully copied CRT.png to userdata theme override (consoles)" >> "$LOG_FILE"
            else
                echo "[$(date +"%H:%M:%S")]: ERROR: Failed to copy CRT.png to userdata theme override" >> "$LOG_FILE"
            fi
        else
            echo "[$(date +"%H:%M:%S")]: WARNING: CRT.png source file not found" >> "$LOG_FILE"
        fi
        
        # Copy CRT.svg
        if [ -f "/userdata/system/Batocera-CRT-Script/Geometry_modeline/CRT.svg" ]; then
            if cp /userdata/system/Batocera-CRT-Script/Geometry_modeline/CRT.svg /userdata/themes/es-theme-carbon/art/logos/CRT.svg 2>>"$LOG_FILE"; then
                chmod 644 /userdata/themes/es-theme-carbon/art/logos/CRT.svg 2>/dev/null || true
                echo "[$(date +"%H:%M:%S")]: Successfully copied CRT.svg to userdata theme override (logos)" >> "$LOG_FILE"
            else
                echo "[$(date +"%H:%M:%S")]: ERROR: Failed to copy CRT.svg to userdata theme override" >> "$LOG_FILE"
            fi
        else
            echo "[$(date +"%H:%M:%S")]: WARNING: CRT.svg source file not found" >> "$LOG_FILE"
        fi
        
        # Also copy to /usr/share/ for immediate visibility (before EmulationStation restart)
        # This ensures files are visible immediately, userdata override ensures persistence
        mkdir -p /usr/share/emulationstation/themes/es-theme-carbon/art/consoles 2>/dev/null || true
        mkdir -p /usr/share/emulationstation/themes/es-theme-carbon/art/logos 2>/dev/null || true
        cp /userdata/system/Batocera-CRT-Script/Geometry_modeline/CRT.png /usr/share/emulationstation/themes/es-theme-carbon/art/consoles/CRT.png 2>/dev/null || true
        cp /userdata/system/Batocera-CRT-Script/Geometry_modeline/CRT.svg /usr/share/emulationstation/themes/es-theme-carbon/art/logos/CRT.svg 2>/dev/null || true
        chmod 644 /usr/share/emulationstation/themes/es-theme-carbon/art/consoles/CRT.png 2>/dev/null || true
        chmod 644 /usr/share/emulationstation/themes/es-theme-carbon/art/logos/CRT.svg 2>/dev/null || true
        echo "[$(date +"%H:%M:%S")]: Also copied to /usr/share/ for immediate visibility" >> "$LOG_FILE"
        
        # Restart EmulationStation to pick up theme assets immediately
        echo "[$(date +"%H:%M:%S")]: Restarting EmulationStation to load CRT theme assets..." >> "$LOG_FILE"
        killall emulationstation 2>/dev/null || true
        sleep 2
        # EmulationStation will auto-restart via openbox/emulationstation-standalone
    else
        echo "[$(date +"%H:%M:%S")]: CRT Mode: Skipping theme asset copy (overlay contains files in /usr/share/)" >> "$LOG_FILE"
    fi
    
    # Step 5: Set permissions (CRT Mode only)
    if [ "$mode" = "crt" ]; then
        chmod 755 "$CRT_ROMS/crt/es_adjust_tool.sh" 2>/dev/null || true
        chmod 755 "$CRT_ROMS/crt/geometry.sh" 2>/dev/null || true
        chmod 755 /userdata/system/Batocera-CRT-Script/Geometry_modeline/es_tool.sh 2>/dev/null || true
        chmod 755 /userdata/system/Batocera-CRT-Script/Geometry_modeline/geometry.sh 2>/dev/null || true
        chmod 0644 "$CRT_ROMS/crt/es_adjust_tool.sh.keys" 2>/dev/null || true
        chmod 0644 "$CRT_ROMS/crt/geometry.sh.keys" 2>/dev/null || true
        chmod 755 "$CRT_ROMS/crt/grid_tool.sh" 2>/dev/null || true
        chmod 755 /userdata/system/Batocera-CRT-Script/Geometry_modeline/grid_tool.sh 2>/dev/null || true
        chmod 0644 "$CRT_ROMS/crt/grid_tool.sh.keys" 2>/dev/null || true
    fi
    
    # Step 6: Ensure Mode Switcher is executable
    if [ -f "/userdata/system/Batocera-CRT-Script/Geometry_modeline/mode_switcher.sh" ]; then
        chmod 755 /userdata/system/Batocera-CRT-Script/Geometry_modeline/mode_switcher.sh 2>/dev/null || true
    fi
    
    # Step 7: Create mode backup directories (if needed)
    mkdir -p "$MODE_BACKUP_DIR/hd_mode" 2>/dev/null || true
    mkdir -p "$MODE_BACKUP_DIR/crt_mode" 2>/dev/null || true
    mkdir -p "$MODE_BACKUP_DIR/hd_mode/boot_configs" 2>/dev/null || true
    mkdir -p "$MODE_BACKUP_DIR/hd_mode/userdata_configs" 2>/dev/null || true
    mkdir -p "$MODE_BACKUP_DIR/hd_mode/emulator_configs" 2>/dev/null || true
    mkdir -p "$MODE_BACKUP_DIR/hd_mode/video_settings" 2>/dev/null || true
    mkdir -p "$MODE_BACKUP_DIR/crt_mode/boot_configs" 2>/dev/null || true
    mkdir -p "$MODE_BACKUP_DIR/crt_mode/userdata_configs" 2>/dev/null || true
    mkdir -p "$MODE_BACKUP_DIR/crt_mode/emulator_configs" 2>/dev/null || true
    mkdir -p "$MODE_BACKUP_DIR/crt_mode/video_settings" 2>/dev/null || true
    
    # Step 8: Set CRT.emulator and CRT.core in batocera.conf
    if [ -f "/userdata/system/batocera.conf" ]; then
        sed -i '/^CRT\.emulator=/d' /userdata/system/batocera.conf 2>/dev/null || true
        sed -i '/^CRT\.core=/d' /userdata/system/batocera.conf 2>/dev/null || true
        
        if ! grep -q "^##  CRT SYSTEM SETTINGS" /userdata/system/batocera.conf 2>/dev/null; then
            echo "" >> /userdata/system/batocera.conf
            echo "###################################################" >> /userdata/system/batocera.conf
            echo "##  CRT SYSTEM SETTINGS" >> /userdata/system/batocera.conf
            echo "###################################################" >> /userdata/system/batocera.conf
        fi
        echo "CRT.emulator=sh" >> /userdata/system/batocera.conf
        echo "CRT.core=sh" >> /userdata/system/batocera.conf
        echo "[$(date +"%H:%M:%S")]: Set CRT.emulator=sh and CRT.core=sh" >> "$LOG_FILE"
    fi
    
    # Step 9: Copy overlays_overrides.sh (CRT Mode only)
    if [ "$mode" = "crt" ]; then
        if [ -f "/userdata/system/Batocera-CRT-Script/extra/overlays_overrides.sh" ]; then
            cp /userdata/system/Batocera-CRT-Script/extra/overlays_overrides.sh "$CRT_ROMS/crt/" 2>/dev/null || true
            chmod 755 "$CRT_ROMS/crt/overlays_overrides.sh" 2>/dev/null || true
        fi
        if [ -f "/userdata/system/Batocera-CRT-Script/extra/overlays_overrides.sh.keys" ]; then
            cp /userdata/system/Batocera-CRT-Script/extra/overlays_overrides.sh.keys "$CRT_ROMS/crt/" 2>/dev/null || true
            chmod 644 "$CRT_ROMS/crt/overlays_overrides.sh.keys" 2>/dev/null || true
        fi
    fi
    
    # Step 10: Final sync and remount boot partition read-only
    sync 2>/dev/null || true
    mount -o remount,ro /boot 2>/dev/null || true
    
    # Step 11: Verify es_systems_crt.cfg
    echo "[$(date +"%H:%M:%S")]: Verifying es_systems_crt.cfg..." >> "$LOG_FILE"
    if [ -f "/userdata/system/configs/emulationstation/es_systems_crt.cfg" ]; then
        if grep -qE "emulatorlauncher|crt-launcher" /userdata/system/configs/emulationstation/es_systems_crt.cfg 2>/dev/null; then
            echo "[$(date +"%H:%M:%S")]: VERIFIED: es_systems_crt.cfg is correct" >> "$LOG_FILE"
        else
            echo "[$(date +"%H:%M:%S")]: ERROR: es_systems_crt.cfg missing launcher command - RE-COPYING..." >> "$LOG_FILE"
            if [ -f "/userdata/system/Batocera-CRT-Script/Geometry_modeline/es_systems_crt.cfg" ]; then
                cp /userdata/system/Batocera-CRT-Script/Geometry_modeline/es_systems_crt.cfg /userdata/system/configs/emulationstation/es_systems_crt.cfg 2>/dev/null || true
                chmod 644 /userdata/system/configs/emulationstation/es_systems_crt.cfg 2>/dev/null || true
                sync 2>/dev/null || true
            fi
        fi
    else
        echo "[$(date +"%H:%M:%S")]: ERROR: es_systems_crt.cfg does NOT exist - RE-COPYING..." >> "$LOG_FILE"
        if [ -f "/userdata/system/Batocera-CRT-Script/Geometry_modeline/es_systems_crt.cfg" ]; then
            mkdir -p /userdata/system/configs/emulationstation 2>/dev/null || true
            cp /userdata/system/Batocera-CRT-Script/Geometry_modeline/es_systems_crt.cfg /userdata/system/configs/emulationstation/es_systems_crt.cfg 2>/dev/null || true
            chmod 644 /userdata/system/configs/emulationstation/es_systems_crt.cfg 2>/dev/null || true
            sync 2>/dev/null || true
        fi
    fi
    
    # Verify CRT Tools directory
    if [ ! -d "$CRT_ROMS/crt" ]; then
        echo "[$(date +"%H:%M:%S")]: ERROR: $CRT_ROMS/crt does NOT exist!" >> "$LOG_FILE"
    else
        echo "[$(date +"%H:%M:%S")]: VERIFIED: $CRT_ROMS/crt exists" >> "$LOG_FILE"
        ls -la "$CRT_ROMS/crt/"*.sh 2>/dev/null | head -5 >> "$LOG_FILE" || true
    fi
    
    #############################################################################
    # APPLY VIDEO OUTPUT IMMEDIATELY (Batocera Native Command)
    # Note: X11 configs (like 10-monitor.conf) are now handled by overlay swap
    #############################################################################
    
    # Apply output change immediately using Batocera's native command
    if [ -n "$video_output" ]; then
        echo "[$(date +"%H:%M:%S")]: Applying video output change immediately: $video_output" >> "$LOG_FILE"
        if [ -x "/usr/bin/batocera-resolution" ]; then
            /usr/bin/batocera-resolution setOutput "$video_output" >> "$LOG_FILE" 2>&1
            echo "[$(date +"%H:%M:%S")]: batocera-resolution setOutput $video_output executed" >> "$LOG_FILE"
        else
            echo "[$(date +"%H:%M:%S")]: WARNING: batocera-resolution not found or not executable" >> "$LOG_FILE"
        fi
    fi
    
    echo "[$(date +"%H:%M:%S")]: Restore completed for $mode mode (userdata-only approach)" >> "$LOG_FILE"
    return 0
}

