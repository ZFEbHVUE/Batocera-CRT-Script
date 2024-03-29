#!/bin/bash

# Check if dialog package is installed
if ! command -v dialog &> /dev/null; then
    echo "Error: dialog package is not installed. Please install it."
    exit 1
fi

# Function to download files and display progress
download_file() {
    URL=$1
    DEST=$2
    wget --progress=bar:force -O "$DEST" "$URL" 2>&1 | \
        dialog --backtitle "Downloading Files" --title "Download Progress" --gauge "Downloading $DEST" 10 70
}

# Function to display a message box
msgbox() {
    dialog --backtitle "Downloading Files" --title "Message" --msgbox "$1" 8 50
}

# Downloading the files directly to /lib & /usr/lib
download_file "https://archive.org/download/install-vnc_server_batocera/libcrypt.so.1" "/lib/libcrypt.so.1"
download_file "https://archive.org/download/install-vnc_server_batocera/libcrypt.so.1" "/usr/lib/libcrypt.so.1"
download_file "https://archive.org/download/install-vnc_server_batocera/libvncclient.so.1" "/usr/lib/libvncclient.so.1"
download_file "https://archive.org/download/install-vnc_server_batocera/libvncserver.so.1" "/usr/lib/libvncserver.so.1"
download_file "https://archive.org/download/install-vnc_server_batocera/libsasl2.so.2" "/usr/lib/libsasl2.so.2"

# Downloading the vnc binary directly to /usr/bin and granting execution permissions
download_file "https://archive.org/download/install-vnc_server_batocera/vnc" "/usr/bin/vnc"
chmod +x /usr/bin/vnc

# Downloading the vnc binary directly to /usr/bin and granting execution permissions
download_file "https://archive.org/download/install-vnc_server_batocera/x11vnc" "/usr/bin/x11vnc"
chmod +x /usr/bin/x11vnc

# Save overlay
batocera-save-overlay

# Display message
msgbox "Files downloaded and configured successfully. Please Reboot"

# Clear the terminal
clear
