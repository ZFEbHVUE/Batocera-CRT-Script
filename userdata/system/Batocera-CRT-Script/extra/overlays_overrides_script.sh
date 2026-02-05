#!/bin/bash

# Display initial message box with centered text.
dialog --title "Important Information" \
       --msgbox "\nThis tool installs scaling override files (and optionally overlays) for handheld systems.\
\n\nIt is intended for 15 kHz CRT profiles (including super resolutions).\
\n\nKnown working profiles include:\
\n   - NTSC\
\n   - generic_15\
\n   - arcade_15\
\n" 16 70

# Paths
SRC_CONFIG_DIR="/userdata/system/Batocera-CRT-Script/extra/config"
SRC_OVERLAY_BORDERS_DIR="/userdata/system/Batocera-CRT-Script/extra/overlays/borders"

DEST_CONFIG_DIR="/userdata/system/configs/retroarch/config"
DEST_OVERLAY_BORDERS_DIR="/userdata/system/configs/retroarch/overlays/borders"

# batocera.conf tweak backup/restore (so Uninstall can revert cleanly)
BATOCERA_CONF="/userdata/system/batocera.conf"
BACKUP_DIR="/userdata/system/Batocera-CRT-Script/extra/.scaling_tool_backup"
BATOCERA_CONF_BACKUP_FILE="$BACKUP_DIR/batocera.conf.keys.backup"

# Save original values for keys we modify in batocera.conf.
# We only create this backup once (on first install), so Uninstall can restore the user's original settings.
backup_batocera_conf_tweaks() {
    local keys=("lynx.core" "lynx.emulator" "nds.melonds_screen_layout" "nds.screens_layout")

    # Don't overwrite an existing backup (keeps the true original state)
    if [ -f "$BATOCERA_CONF_BACKUP_FILE" ]; then
        return 0
    fi

    mkdir -p "$BACKUP_DIR" 2>/dev/null

    {
        echo "# Batocera-CRT-Script Scaling Tool - batocera.conf key backup"
        echo "# Created: $(date)"
        for k in "${keys[@]}"; do
            if grep -q "^${k}=" "$BATOCERA_CONF" 2>/dev/null; then
                # Store the *value* only (can include spaces)
                local v
                v="$(grep -m1 "^${k}=" "$BATOCERA_CONF" | sed "s/^${k}=//")"
                printf '%s|present|%s\n' "$k" "$v"
            else
                printf '%s|absent|\n' "$k"
            fi
        done
    } > "$BATOCERA_CONF_BACKUP_FILE"
}

restore_batocera_conf_tweaks() {
    local keys=("lynx.core" "lynx.emulator" "nds.melonds_screen_layout" "nds.screens_layout")

    # If we have a real backup, restore exactly.
    if [ -f "$BATOCERA_CONF_BACKUP_FILE" ]; then
        while IFS='|' read -r key status value; do
            # Skip comments/empty lines
            [ -z "$key" ] && continue
            [[ "$key" == \#* ]] && continue

            # Remove any existing lines for the key (including duplicates)
            sed -i "/^${key}=.*/d" "$BATOCERA_CONF"

            if [ "$status" = "present" ]; then
                echo "${key}=${value}" >> "$BATOCERA_CONF"
            fi
        done < "$BATOCERA_CONF_BACKUP_FILE"

        # Backup is one-time-use: after a successful restore, remove it
        rm -f "$BATOCERA_CONF_BACKUP_FILE" 2>/dev/null

        return 0
    fi

    # No backup found: do a safe best-effort revert (only remove the exact values we enforce)
    sed -i '/^lynx.core=handy$/d' "$BATOCERA_CONF"
    sed -i '/^lynx.emulator=libretro$/d' "$BATOCERA_CONF"
    sed -i '/^nds.melonds_screen_layout=Top Only$/d' "$BATOCERA_CONF"
    sed -i '/^nds.screens_layout=top only$/d' "$BATOCERA_CONF"

    return 0
}

# Apply required batocera.conf tweaks (used by both install methods)
apply_batocera_conf_tweaks() {
    CONFIG_FILE="/userdata/system/batocera.conf"

    # Remove duplicates of lynx lines if they exist
    sed -i '/^lynx.core=handy/d' "$CONFIG_FILE"
    sed -i '/^lynx.emulator=libretro/d' "$CONFIG_FILE"

    if grep -q "^lynx.core=mednafen_lynx" "$CONFIG_FILE"; then
        # Replace the line and ensure lynx.emulator is present
        sed -i 's/^lynx.core=mednafen_lynx/lynx.core=handy/' "$CONFIG_FILE"
        if ! grep -q "^lynx.emulator=libretro" "$CONFIG_FILE"; then
            sed -i '/^lynx.core=handy/a lynx.emulator=libretro' "$CONFIG_FILE"
        fi
    else
        # Add lines to the end of the file if not present
        echo "lynx.core=handy" >> "$CONFIG_FILE"
        echo "lynx.emulator=libretro" >> "$CONFIG_FILE"
    fi

    # Remove duplicates of nds lines if they exist
    sed -i '/^nds.melonds_screen_layout=Top Only/d' "$CONFIG_FILE"
    sed -i '/^nds.screens_layout=top only/d' "$CONFIG_FILE"

    # Check and replace or add nds.melonds_screen_layout
    if grep -q "^nds.melonds_screen_layout=" "$CONFIG_FILE"; then
        sed -i 's/^nds.melonds_screen_layout=.*/nds.melonds_screen_layout=Top Only/' "$CONFIG_FILE"
    else
        echo "nds.melonds_screen_layout=Top Only" >> "$CONFIG_FILE"
    fi

    # Check and replace or add nds.screens_layout
    if grep -q "^nds.screens_layout=" "$CONFIG_FILE"; then
        sed -i 's/^nds.screens_layout=.*/nds.screens_layout=top only/' "$CONFIG_FILE"
    else
        echo "nds.screens_layout=top only" >> "$CONFIG_FILE"
    fi
}

# Function: Install Overlays & Scaling files
install_overlays_and_scaling() {
    # Check for existing files
    if [ -d "$DEST_CONFIG_DIR" ] || [ -d "$DEST_OVERLAY_BORDERS_DIR" ]; then
        dialog --title "Confirmation" \
               --yesno "Existing RetroArch scaling/overlay files were detected.\n\nOverwrite the existing files?" 11 60
        response=$?
        if [ $response -ne 0 ]; then
            return
        fi
    fi

    # Create target directories if they don't exist
    mkdir -p "$DEST_CONFIG_DIR"
    mkdir -p "$DEST_OVERLAY_BORDERS_DIR"

    # Copy scaling override files and set permissions
    cp -r "$SRC_CONFIG_DIR/." "$DEST_CONFIG_DIR/"
    chmod -R u+rw,go+rw "$DEST_CONFIG_DIR/"

    # Copy overlays (borders only) and set permissions
    cp -r "$SRC_OVERLAY_BORDERS_DIR/." "$DEST_OVERLAY_BORDERS_DIR/"
    chmod -R u+rw,go+rw "$(dirname "$DEST_OVERLAY_BORDERS_DIR")/"

    # Ensure Uninstall can restore the user's original batocera.conf values
    backup_batocera_conf_tweaks
    apply_batocera_conf_tweaks

    dialog --title "Success" --msgbox "Overlays and scaling files have been installed successfully." 10 65
}

# Function: Install Scaling files only (NO Overlays)
install_scaling_only() {
    if [ -d "$DEST_CONFIG_DIR" ]; then
        dialog --title "Confirmation" \
               --yesno "Existing RetroArch scaling override files were detected.\n\nOverwrite the existing files?" 11 62
        response=$?
        if [ $response -ne 0 ]; then
            return
        fi
    fi

    mkdir -p "$DEST_CONFIG_DIR"

    cp -r "$SRC_CONFIG_DIR/." "$DEST_CONFIG_DIR/"
    chmod -R u+rw,go+rw "$DEST_CONFIG_DIR/"

    # Ensure Uninstall can restore the user's original batocera.conf values
    backup_batocera_conf_tweaks
    apply_batocera_conf_tweaks

    dialog --title "Success" --msgbox "Scaling files have been installed successfully (no overlays were installed)." 10 72
}

# Function for Uninstall
uninstall_files() {
    dialog --title "Confirmation" \
           --yesno "This will uninstall scaling override files and (if present) the handheld overlays.\n\nContinue?" 11 70
    response=$?
    if [ $response -ne 0 ]; then
        return  # Go back to the menu
    fi

    local had_backup=0
    if [ -f "$BATOCERA_CONF_BACKUP_FILE" ]; then
        had_backup=1
    fi

    # Remove specified folders from the config directory
	CONFIG_DIR="/userdata/system/configs/retroarch/config"
    rm -rf "$CONFIG_DIR/arduous" \
           "$CONFIG_DIR/Beetle NeoPop" \
           "$CONFIG_DIR/DeSmuME" \
           "$CONFIG_DIR/fake-08" \
           "$CONFIG_DIR/Gambatte" \
           "$CONFIG_DIR/Genesis Plus GX" \
           "$CONFIG_DIR/Handy" \
           "$CONFIG_DIR/melonDS" \
           "$CONFIG_DIR/mGBA" \
           "$CONFIG_DIR/VBA-M"

    # Remove specified folders from the overlays/borders directory (if present)
    OVERLAY_BORDERS="$DEST_OVERLAY_BORDERS_DIR"
    rm -rf "$OVERLAY_BORDERS/Arduboy" \
           "$OVERLAY_BORDERS/Assets Transparancy" \
           "$OVERLAY_BORDERS/Atari Lynx Horizontal" \
           "$OVERLAY_BORDERS/Game Gear" \
           "$OVERLAY_BORDERS/GameBoy" \
           "$OVERLAY_BORDERS/GameBoy Advance" \
           "$OVERLAY_BORDERS/GameBoy Color" \
           "$OVERLAY_BORDERS/Nintendo DS" \
           "$OVERLAY_BORDERS/Pico-8" \
           "$OVERLAY_BORDERS/Super GameBoy"

    # Revert batocera.conf tweaks
    restore_batocera_conf_tweaks

    if [ $had_backup -eq 1 ]; then
        dialog --title "Success" --msgbox "Files have been uninstalled successfully.\n\nBatocera.conf settings were restored to your original values." 12 70
    else
        dialog --title "Success" --msgbox "Files have been uninstalled successfully.\n\nNote: No batocera.conf backup was found, so a safe best-effort revert was used (it only removes the exact values this tool sets)." 14 72
    fi
}

# Infinite loop for menu selection
while true; do
    choice=$(dialog --title "Overlays & Scaling Files" \
                    --clear \
                    --nocancel \
                    --no-tags \
                    --menu "Install / Uninstall" 21 85 12 \
                    "Install_All" "Install Overlays & Scaling files" \
                    "Install_Scaling" "Install Scaling files only (NO Overlays)" \
                    "Uninstall" "Uninstall Scaling files (and Overlays if installed)" \
                    "Quit" "Exit back to Emulation Station" \
                    3>&1 1>&2 2>&3)
    
    case $choice in
        Install_All)
            install_overlays_and_scaling
            ;;
        Install_Scaling)
            install_scaling_only
            ;;
        Uninstall)
            uninstall_files
            ;;
        Quit)
            clear
            exit 0
            ;;
    esac
done
