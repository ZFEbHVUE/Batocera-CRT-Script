#!/bin/bash

# Display initial message box with centered text.
dialog --title "Important Information" \
       --msgbox "\nThe tool installs override files for handheld systems and adds overlays. \
\n\nIt will only work for 15khz profiles not limited to super resolutions. \
\n\nWorks with the following profiles: \
\n\n   - NTSC \
\n   - generic_15 \
\n   - arcade_15 \
\n" 15 70

# Function for Install
install_files() {
    # Check for existing files
    if [ -d "/userdata/system/configs/retroarch/config" ] || [ -d "/userdata/system/configs/retroarch/overlays" ]; then
        dialog --title "Confirmation" \
               --yesno "The installation has detected files already present.\nWould you like to overwrite them?" 10 50
        response=$?
        if [ $response -ne 0 ]; then
            return  # Go back to the menu
        fi
    fi
    
    # Create target directories if they don't exist
    mkdir -p /userdata/system/configs/retroarch/config
    mkdir -p /userdata/system/configs/retroarch/overlays

    # Copy files and set permissions
    cp -r /userdata/system/Batocera-CRT-Script/extra/config/. /userdata/system/configs/retroarch/config/
    cp -r /userdata/system/Batocera-CRT-Script/extra/overlays/. /userdata/system/configs/retroarch/overlays/
    chmod -R u+rw,go+rw /userdata/system/configs/retroarch/config/
    chmod -R u+rw,go+rw /userdata/system/configs/retroarch/overlays/

    # Edit batocera.conf
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

    dialog --title "Success" --msgbox "Files have been installed successfully." 10 50
}

# Function for Uninstall
uninstall_files() {
    dialog --title "Confirmation" \
           --yesno "This will uninstall the override and overlays files.\nWould you like to remove them?" 10 50
    response=$?
    if [ $response -ne 0 ]; then
        return  # Go back to the menu
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

    # Remove specified folders from the overlays/borders directory
    OVERLAY_BORDERS="/userdata/system/configs/retroarch/overlays/borders"
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

    dialog --title "Success" --msgbox "Files have been uninstalled successfully." 10 50
}

# Infinite loop for menu selection
while true; do
    choice=$(dialog --title "Overlay & Override files Selection" \
                    --clear \
                    --nocancel \
                    --menu "Overlay & Override Install / Uninstall" 20 80 10 \
                    "Install" "Install overlay & override files" \
                    "Uninstall" "Removes overlay & override files" \
                    "Quit" "Exit back to Emulation Station" \
                    3>&1 1>&2 2>&3)
    
    case $choice in
        Install)
            install_files
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
