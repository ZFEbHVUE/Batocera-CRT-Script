#!/bin/bash

# Define the directory path
log_dir="/userdata/system/Batocera-CRT-Script/Geometry_modeline/backup/"

# Define the path to the log file
log_file="${log_dir}backup.file"

# Check if the directory exists
if [ ! -d "$log_dir" ]; then
    # Create the directory if it doesn't exist
    mkdir -p "$log_dir"
fi

# Trap to clear the terminal if the user presses pause/break key
trap clear_terminal SIGINT

# Function to clear the terminal
clear_terminal() {
    clear
    exit 0
}

# Function to make the boot partition writable
making_boot_writable() {
    dialog --title "Boot Partition" \
           --msgbox "Making Boot Writable" 10 40
    mount -o remount,rw /boot
}

# Function to save overlay file without progress bar
saving_overlay_file() {
    batocera-save-overlay
    local exit_status=$?
    if [ $exit_status -eq 0 ]; then
        dialog --title "Overlay Saved" --msgbox "Overlay file saved successfully. Please reboot to apply the changes" 10 40
    else
        dialog --title "Error" --msgbox "Failed to save overlay file." 10 40
    fi
}

# Check if both files exist before performing the backup
if [ -f "/userdata/system/99-nvidia.conf" ] && [ -e "$log_file" ]; then
    echo "Both 99-nvidia.conf and log file exist. Skipping backup."
elif [ -f "/userdata/system/99-nvidia.conf" ]; then
    # Backup 99-nvidia.conf and switchres.ini files 
    install -D -m 0755 /etc/switchres.ini "$log_dir/etc/switchres.ini.backup"
    install -D -m 0644 /userdata/system/99-nvidia.conf "$log_dir/userdata/system/99-nvidia.conf.backup"
    # Create the log file
    touch "$log_file"
else
    # Call the function to make the boot partition writable
    making_boot_writable
    
    # Check if the log file exists
    if [ -e "$log_file" ]; then
        echo "Syslinux files and switchres.ini backup already performed."
    else
        echo "Backing up syslinux and switchres.ini files..."

        # Backup syslinux.cfg files and switchres.ini
        install -D -m 0755 /etc/switchres.ini "$log_dir/etc/switchres.ini.backup"
        install -D -m 0755 /boot/boot/syslinux.cfg "$log_dir/boot/boot/syslinux.cfg.backup"
        install -D -m 0755 /boot/boot/syslinux/syslinux.cfg "$log_dir/boot/boot/syslinux.cfg.backup"
        install -D -m 0755 /boot/EFI/syslinux.cfg "$log_dir/boot/EFI/syslinux.cfg.backup"
        install -D -m 0755 /boot/EFI/BOOT/syslinux.cfg "$log_dir/boot/EFI/BOOT/syslinux.cfg.backup"
        install -D -m 0755 /boot/EFI/batocera/syslinux.cfg "$log_dir/boot/EFI/batocera/syslinux.cfg.backup"

        # Create the log file
        touch "$log_file"

        echo "Syslinux files and switchres.ini backed up successfully."
    fi
fi

clear

# Read Monitor Type and Boot Resolution from BootRes.log
monitor_type=$(grep "Monitor Type:" /userdata/system/logs/BootRes.log | awk -F': ' '{print $2}')
boot_resolution=$(grep "Boot Resolution:" /userdata/system/logs/BootRes.log | awk -F': ' '{print $2}')

## Read Monitor Type and Boot Resolution from BootRes.log
#monitor_type=$(extract_value "Monitor Type")
#boot_resolution=$(extract_value "Boot Resolution")

# Dialog to display Monitor Type and Boot Resolution
dialog --title "Monitor Information" \
       --msgbox "Your Monitor Type: $monitor_type\nYour Boot Resolution is: $boot_resolution" 10 60
clear

# Extract refresh rate from Boot Resolution
refresh_rate=$(echo "$boot_resolution" | grep -oP '@\K\d+')

# Check if the Boot Resolution is disallowed
disallowed_resolutions=("800x600@60" "1027x576@50" "1027x576@25" "1024x576@25" "1024x768@25" "1024x768@50")
if [[ " ${disallowed_resolutions[@]} " =~ " $boot_resolution " ]]; then
    dialog --title "Unsupported Resolution" \
           --yesno "Your boot resolution is set for $boot_resolution which is not supported.\nWould you like to run the geometry script for the following resolutions?\n\n640x480@60 (Default Recommended)\n320x240@60\n768x576@50" 12 60
    case $? in
        0)
            ;;
        *)
            echo "Exiting."
            clear_terminal
            ;;
    esac
fi
clear


# Function to restore syslinux files and switchres.ini
restore_syslinux_files() {
    if [ -f "/userdata/system/99-nvidia.conf" ]; then
        # Restoring 99-nvidia.conf and switchres.ini files if 99-nvidia.conf exists
        echo "Restoring 99-nvidia.conf and switchres.ini files..."

        install -D -m 0755 /userdata/system/Batocera-CRT-Script/Geometry_modeline/backup/etc/switchres.ini.backup /etc/switchres.ini
        install -D -m 0644 /userdata/system/Batocera-CRT-Script/Geometry_modeline/backup/userdata/system/99-nvidia.conf.backup /userdata/system/99-nvidia.conf

        echo "99-nvidia.conf & switchres.ini successfully restored."

        # Reboot or exit
        dialog --title "Reboot or Exit" \
               --yesno "99-nvidia.conf & switchres.ini files restored successfully.\nDo you want to reboot the system?" 10 40
        response=$?
        case $response in
            0)  # User selected Yes, so reboot the system
                reboot
                ;;
			*)  # User selected No, so exit the script
				clear_terminal  # Call the function to clear the terminal and exit
				;;
        esac
    else
		# Remount /boot as read-write
		mount -o remount,rw /boot

        # Restore syslinux files if 99-nvidia.conf does not exist
        echo "Restoring syslinux files and switchres.ini..."

        install -D -m 0755 /userdata/system/Batocera-CRT-Script/Geometry_modeline/backup/etc/switchres.ini.backup /etc/switchres.ini
        install -D -m 0755 /userdata/system/Batocera-CRT-Script/Geometry_modeline/backup/boot/boot/syslinux.cfg.backup /boot/boot/syslinux.cfg
        install -D -m 0755 /userdata/system/Batocera-CRT-Script/Geometry_modeline/backup/boot/boot/syslinux.cfg.backup /boot/boot/syslinux/syslinux.cfg 
        install -D -m 0755 /userdata/system/Batocera-CRT-Script/Geometry_modeline/backup/boot/EFI/syslinux.cfg.backup /boot/EFI/syslinux.cfg
        install -D -m 0755 /userdata/system/Batocera-CRT-Script/Geometry_modeline/backup/boot/EFI/BOOT/syslinux.cfg.backup /boot/EFI/BOOT/syslinux.cfg
        install -D -m 0755 /userdata/system/Batocera-CRT-Script/Geometry_modeline/backup/boot/EFI/batocera/syslinux.cfg.backup /boot/EFI/batocera/syslinux.cfg

        echo "Syslinux files restored successfully."

        # Reboot or exit
        dialog --title "Reboot or Exit" \
               --yesno "Syslinux files restored successfully.\nDo you want to reboot the system?" 10 40
        response=$?
        case $response in
            0)  # User selected Yes, so reboot the system
                reboot
                ;;
			*)  # User selected No, so exit the script
				clear_terminal  # Call the function to clear the terminal and exit
				;;
        esac
    fi
}


# Set a variable to control the visibility of the "Custom Resolution" option
show_custom_resolution=true

# Function to handle custom resolution input
handle_custom_resolution() {
    # Prompt for custom resolution
    resolution_input=$(dialog --title "Custom Resolution" \
                              --clear \
                              --inputbox "Enter your custom resolution in the format 'WIDTHxHEIGHT@REFRESH_RATE, Example 1024x768x60':" 10 60 \
                              3>&1 1>&2 2>&3)
    # Check if the user pressed cancel
    if [ -z "$resolution_input" ]; then
        return 1  # Signal to continue resolution selection
    fi
    # Extract width, height, and refresh rate from the input
    width=$(echo $resolution_input | cut -d'x' -f1)
    height=$(echo $resolution_input | cut -d'x' -f2 | cut -d'@' -f1)
    refresh_rate=$(echo $resolution_input | cut -d'@' -f2)
    
    # Adjust width component
    adjusted_width=$((width + 1))
    width=$adjusted_width
    
    return 0  # Signal to break out of the loop
}

# Dialog to select resolution
while true; do
    choice=$(dialog --title "Resolution Selection" \
                    --clear \
                    --nocancel \
                    --menu "Choose your resolution" 20 80 10 \
                    "640x480@60" "640x480 60Hz (Default Recommended)" \
                    "320x240@60" "320x240 60Hz" \
                    "768x576@50" "768x576 50Hz" \
                    $(if $show_custom_resolution; then echo '"Custom Resolution" "Enter a custom resolution"'; fi) \
                    "Restore Files" "Revert changes and restore" \
                    "Quit" "Exit back to terminal" \
                    3>&1 1>&2 2>&3)

    case $choice in
        "640x480@60")
            width=640
            height=480
            refresh_rate=60
            break
            ;;
        "320x240@60")
            width=320
            height=240
            refresh_rate=60
            break
            ;;
        "768x576@50")
            width=768
            height=576
            refresh_rate=50
            break
            ;;
        "Custom Resolution")
            if $show_custom_resolution; then
                handle_custom_resolution
                if [ $? -eq 0 ]; then
                    break
                else
                    continue  # Go back to resolution selection
                fi
            else
                echo "Custom resolution option is disabled."
                continue  # Go back to resolution selection
            fi
            ;;
        "Restore Files")
            restore_syslinux_files  # Call the function to restore syslinux files
            break
            ;;
        "Quit")
            echo "Exiting."
            clear_terminal
            ;;
        *)
            echo "Invalid option. Exiting."
            clear_terminal
            ;;
    esac
done

# Run the Python script with the selected resolution and refresh rate
output=$(/usr/bin/geometry "$width" "$height" "$refresh_rate")

# Check if the output contains "Aborted!"
if [[ $output == *"Aborted!"* ]]; then
    dialog --title "Aborted" \
           --msgbox "Aborted! No changes made to switchres.ini." 10 40
    clear_terminal
fi

# Extract the final crt_range value from the output
crt_range_value=$(echo "$output" | grep -oP 'Final crt_range: \K.*')

# Update switchres.ini
sed -i "s/^\s*monitor\s*\(generic_15\|ntsc\|pal\|arcade_15\|arcade_15ex\|arcade_25\|arcade_31\|arcade_15_25\|arcade_15_25_31\|vesa_480\|vesa_600\|vesa_768\|vesa_1024\|pc_31_120\|pc_70_120\|h9110\|polo\|pstar\|k7000\|k7131\|d9200\|d9800\|d9400\|m2929\|m3129\|ms2930\|ms929\|r666b\|custom\|lcd\)\s*$/     monitor                   custom/" /etc/switchres.ini
sed -i 's/^\s*crt_range0\s*.*/crt_range0 '"$crt_range_value"'/' /etc/switchres.ini
sed -i 's/^\s*crt_range0\s*.*/    crt_range0                '"$crt_range_value"'/' /etc/switchres.ini

dialog --title "Success" \
       --msgbox "switchres.ini updated successfully." 10 40

# Check if "/userdata/system/99-nvidia.conf" exists
if [ -f "/userdata/system/99-nvidia.conf" ]; then
    # Switchres resolution generation script

    # Read the Boot Resolution from the file
    resolution=$(grep "Boot Resolution:" /userdata/system/logs/BootRes.log | awk -F': ' '{print $2}')

    # Extract resolution components
    IFS="@ " read -r RESOLUTION FREQ <<< "$resolution"
    IFS="x" read -r H_RES_EDID V_RES_EDID <<< "$RESOLUTION"

    # Adjust width component
    adjusted_width=$(( ${H_RES_EDID%%x} + 1 )) # Extract width, add 1
    H_RES_EDID="$adjusted_width"x"$V_RES_EDID"

    # Run switchres and capture its output
    switchres_output=$(switchres "$H_RES_EDID" "$V_RES_EDID" "$FREQ" -f "$H_RES_EDID"x"$V_RES_EDID"@"$FREQ" -i switchres.ini -c | grep "Modeline")

    # Remove leading whitespace
    switchres_output=$(echo "$switchres_output" | sed 's/^[ \t]*//')

    # Prompt the user if they want to edit the existing 99-nvidia.conf file
    dialog --title "99-nvidia.conf Found" \
           --yesno "99-nvidia.conf file is found.\nDo you want to edit it?" 10 40
    response=$?
    case $response in
        0)  # User selected Yes, so proceed with editing
            # Replace the existing Modeline in the file
            sed -i "s/Modeline\s*\"[0-9]*x[0-9]*\".*/$switchres_output/" /userdata/system/99-nvidia.conf
            # Add sed command to replace "Switchres: Modeline " with "Modeline "
            sed -i 's/Switchres: Modeline "/Modeline "/' /userdata/system/99-nvidia.conf
			# Add sed command to remove everything between _ and " including the symbol _
#			sed -i 's/\([^_]*\)_[^"]*/\1"/' /userdata/system/99-nvidia.conf
			sed -i 's/\(Modeline\s*"[^_]*\)_[^"]*"/\1"/' /userdata/system/99-nvidia.conf

			dialog --title "99-nvidia.conf Updated" \
                   --msgbox "99-nvidia.conf updated successfully. Please reboot to apply the changes." 10 40
            ;;
        1)  # User selected No, so exit the script
            dialog --title "99-nvidia.conf Not Modified" \
                   --msgbox "99-nvidia.conf is not modified." 10 40
            clear_terminal
            ;;
        255)  # Dialog was canceled
            dialog --title "99-nvidia.conf Not Modified" \
                   --msgbox "99-nvidia.conf is not modified." 10 40
            clear_terminal
            ;;
    esac
else
    # Original script
    # Call the function to make the boot partition writable
    making_boot_writable

    # EDID generation script

    # Read the Boot Resolution from the file
    resolution=$(grep "Boot Resolution:" /userdata/system/logs/BootRes.log | awk -F': ' '{print $2}')

    # Extract resolution components
    IFS="@ " read -r RESOLUTION FREQ <<< "$resolution"
    IFS="x" read -r H_RES_EDID V_RES_EDID <<< "$RESOLUTION"

    # Adjust width component
    adjusted_width=$(( ${H_RES_EDID%%x} + 1 )) # Extract width, add 1
    H_RES_EDID="$adjusted_width"x"$V_RES_EDID"

    # Generate the EDID file using switchres
    switchres "$H_RES_EDID" "$V_RES_EDID" "$FREQ" -f "$H_RES_EDID"x"$V_RES_EDID"@"$FREQ" -i switchres.ini -e

    # Identify the generated EDID file in the current directory
    edid_file=$(find . -maxdepth 1 -name "*.bin" -print -quit)

    # If an EDID file is found, ask the user if they want to overwrite it
    if [ -f "$edid_file" ]; then
        dialog --title "EDID File Found" \
               --yesno "EDID file named 'custom.bin' is found.\nDo you want to overwrite it?" 10 40
        response=$?
        case $response in
            0)  # User selected Yes, so proceed with overwriting
                mv "$edid_file" custom.bin
                # Remove existing custom.bin if it exists
                rm -f /lib/firmware/edid/custom.bin
                mv custom.bin /lib/firmware/edid/
                dialog --title "EDID File Generated" \
                       --msgbox "EDID file 'custom.bin' generated and moved to /lib/firmware/edid/" 10 40
                ;;
            1)  # User selected No, so exit the script
                dialog --title "EDID File Not Overwritten" \
                       --msgbox "EDID file 'custom.bin' is not overwritten." 10 40
                clear_terminal
                ;;
            255)  # Dialog was canceled
                dialog --title "EDID File Not Overwritten" \
                       --msgbox "EDID file 'custom.bin' is not overwritten." 10 40
                clear_terminal
                ;;
        esac
    else
        dialog --title "EDID File Not Found" \
               --msgbox "Failed to find generated EDID file." 10 40
    fi

    # Define the file paths to update EDID references in syslinux configurations
    paths=(
        "/boot/boot/syslinux.cfg"
        "/boot/boot/syslinux/syslinux.cfg"
        "/boot/EFI/syslinux.cfg"
        "/boot/EFI/BOOT/syslinux.cfg"
        "/boot/EFI/batocera/syslinux.cfg"
    )

    # Iterate over the file paths and update EDID references
    for path in "${paths[@]}"; do
        if [ -f "$path" ]; then
            # Use sed to edit the file
            sed -i 's|:edid/[^[:space:]]*\.bin|:edid/custom.bin|g' "$path"
            echo "File $path edited successfully."
        else
            echo "File not found: $path"
        fi
    done

    # Clear the terminal
    clear

    # Call the function to save overlay file
    saving_overlay_file

    # Clear the terminal
    clear
fi

