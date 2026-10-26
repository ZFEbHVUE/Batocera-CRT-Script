#######################################################################################
# Create Mode Switcher for HD/CRT Mode switching
#######################################################################################
if [ -f "/userdata/system/Batocera-CRT-Script/Geometry_modeline/crt/mode_switcher.sh" ]; then
    # Ensure main script exists and is executable
    if [ -f "/userdata/system/Batocera-CRT-Script/Geometry_modeline/mode_switcher.sh" ]; then
        chmod 755 /userdata/system/Batocera-CRT-Script/Geometry_modeline/mode_switcher.sh
    fi
    
    # Copy mode switcher wrapper to CRT Tools (wrapper launches main script in xterm)
    cp /userdata/system/Batocera-CRT-Script/Geometry_modeline/crt/mode_switcher.sh "$CRT_ROMS/crt/mode_switcher.sh"
    chmod 755 "$CRT_ROMS/crt/mode_switcher.sh"
    # Copy .keys file for controller support
    if [ -f "/userdata/system/Batocera-CRT-Script/Geometry_modeline/crt/mode_switcher.sh.keys" ]; then
        cp /userdata/system/Batocera-CRT-Script/Geometry_modeline/crt/mode_switcher.sh.keys "$CRT_ROMS/crt/mode_switcher.sh.keys"
        chmod 644 "$CRT_ROMS/crt/mode_switcher.sh.keys"
    fi
    
    # Copy gamelist.xml to make Mode Switcher visible in EmulationStation
    if [ -f "/userdata/system/Batocera-CRT-Script/Geometry_modeline/crt/gamelist.xml" ]; then
        cp /userdata/system/Batocera-CRT-Script/Geometry_modeline/crt/gamelist.xml "$CRT_ROMS/crt/gamelist.xml"
        chmod 644 "$CRT_ROMS/crt/gamelist.xml"
    fi
    
    # Create mode backup directories
    mkdir -p /userdata/Batocera-CRT-Script-Backup/mode_backups/hd_mode
    mkdir -p /userdata/Batocera-CRT-Script-Backup/mode_backups/crt_mode
    mkdir -p /userdata/Batocera-CRT-Script-Backup/mode_backups/hd_mode/boot_configs
    mkdir -p /userdata/Batocera-CRT-Script-Backup/mode_backups/hd_mode/emulator_configs
    mkdir -p /userdata/Batocera-CRT-Script-Backup/mode_backups/hd_mode/video_settings
    mkdir -p /userdata/Batocera-CRT-Script-Backup/mode_backups/crt_mode/boot_configs
    mkdir -p /userdata/Batocera-CRT-Script-Backup/mode_backups/crt_mode/emulator_configs
    mkdir -p /userdata/Batocera-CRT-Script-Backup/mode_backups/crt_mode/video_settings
    
    echo "Mode Switcher installed successfully."
else
    echo "Mode Switcher script not found. Skipping installation."
fi

#######################################################################################
# Create geometryForVideomodes.sh  for adjusting resoltuion in videomodes.conf for your CRT
#######################################################################################

#cp Batocera-CRT-Script/Geometry_modeline/crt/geometryForVideomodes.sh /userdata/roms/crt/geometryForVideomodes.sh
#chmod 755 /userdata/roms/crt/geometryForVideomodes.sh

