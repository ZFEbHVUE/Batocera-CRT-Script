#!/bin/bash

# Define the backup directory path
# Keep Geometry Tool backups together with the main Batocera CRT Script backup folder.
backup_root="/userdata/Batocera-CRT-Script-Backup"
log_dir="${backup_root}/Geometry_Tool_Backup/"
old_log_dir="/userdata/system/Batocera-CRT-Script/Geometry_modeline/backup/"

# If an older Geometry Tool backup exists, migrate it to the new backup location.
# This keeps Restore Files working for users who already ran an older version of the tool.
if [ ! -d "$log_dir" ] && [ -d "$old_log_dir" ]; then
    mkdir -p "$log_dir"
    cp -a "${old_log_dir}." "$log_dir" 2>/dev/null
fi

# Check if the directory exists
if [ ! -d "$log_dir" ]; then
    # Create the directory if it doesn't exist
    mkdir -p "$log_dir"
fi

# Define the path to the log file
log_file="${log_dir}backup.file"

# Define key backup file paths used to verify that backups are complete
switchres_backup="${log_dir}etc/switchres.ini.backup"
nvidia_backup="${log_dir}userdata/system/99-nvidia.conf.backup"
syslinux_main_backup="${log_dir}boot/boot/syslinux.cfg.backup"
syslinux_sub_backup="${log_dir}boot/boot/syslinux/syslinux.cfg.backup"
syslinux_efi_backup="${log_dir}boot/EFI/syslinux.cfg.backup"
syslinux_efi_boot_backup="${log_dir}boot/EFI/BOOT/syslinux.cfg.backup"
syslinux_efi_batocera_backup="${log_dir}boot/EFI/batocera/syslinux.cfg.backup"

# Informational dialog box about using the Geometry tool
geometry_tool_warning() {
    dialog --title "Important Notice" \
           --msgbox "The Geometry tool is only to be used after you adjusted the image using the CRT Grid Tool." 10 50
}

# Display the geometry tool warning at the start of the script
geometry_tool_warning

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

GEOMETRY_SYSLINUX_CFGS=(
    /boot/boot/syslinux.cfg
    /boot/boot/syslinux/syslinux.cfg
    /boot/EFI/syslinux.cfg
    /boot/EFI/BOOT/syslinux.cfg
    /boot/EFI/batocera/syslinux.cfg
)

geometry_overlay_saver() {
    local crt="${CRT_SCRIPT_DIR:-/userdata/system/Batocera-CRT-Script}/batocera-save-crt-overlay"
    if grep -q 'BOOT_IMAGE=/crt/linux' /proc/cmdline 2>/dev/null; then
        if [ -f "$crt" ] && [ -x "$crt" ] && [ ! -L "$crt" ]; then
            printf '%s\n' "$crt"
            return 0
        fi
    fi
    if command -v batocera-save-overlay >/dev/null 2>&1; then
        printf '%s\n' batocera-save-overlay
        return 0
    fi
    return 1
}

geometry_revert_switchres_monitor() {
    local preset="$1" swini="/etc/switchres.ini"
    [ -n "$preset" ] || return 1
    [ -f "$swini" ] || return 1
    awk -v preset="$preset" '
        !seen && $0 ~ /^[[:space:]]*monitor[[:space:]]+/ {
            print "     monitor                   " preset
            seen=1
            next
        }
        { print }
        END { if (!seen) print "     monitor                   " preset }
    ' "$swini" > "${swini}.tmp" && mv "${swini}.tmp" "$swini"
}

geometry_sync_syslinux_edid() {
    local bin="$1" path
    [ -n "$bin" ] && [[ "$bin" == *.bin ]] || return 1
    mount -o remount,rw /boot 2>/dev/null || return 1
    for path in "${GEOMETRY_SYSLINUX_CFGS[@]}"; do
        [ -f "$path" ] || continue
        grep -q 'drm\.edid_firmware=' "$path" 2>/dev/null || continue
        sed -i "s|:edid/[^[:space:]]*\\.bin|:edid/${bin}|g" "$path"
    done
    return 0
}

geometry_verify_boot_edid() {
    local want="$1" edid_dir=/lib/firmware/edid path found=0
    [ -f "${edid_dir}/${want}" ] || return 1
    for path in "${GEOMETRY_SYSLINUX_CFGS[@]}"; do
        [ -f "$path" ] || continue
        grep -q 'drm\.edid_firmware=' "$path" 2>/dev/null || continue
        found=1
        grep -m1 'drm\.edid_firmware=' "$path" | grep -Fq ":edid/${want}" || return 1
    done
    [ "$found" -eq 1 ]
}

geometry_finalize_edid_boot() {
    local edid_bin="$1"
    geometry_sync_syslinux_edid "$edid_bin" || return 1
    geometry_verify_boot_edid "$edid_bin" || return 1
    saving_overlay_file || return 1
    return 0
}

# Function to save overlay file without progress bar
saving_overlay_file() {
    local saver exit_status
    saver=$(geometry_overlay_saver) || {
        dialog --title "Error" --msgbox "No overlay save utility found (CRT or stock)." 10 50
        return 1
    }
    "$saver"
    exit_status=$?
    if [ $exit_status -eq 0 ]; then
        dialog --title "Overlay Saved" --msgbox "Overlay file saved successfully. Please reboot to apply the changes" 10 40
    else
        dialog --title "Error" --msgbox "Failed to save overlay file." 10 40
    fi
    return "$exit_status"
}

# Check if both files exist before performing the backup
if [ -f "/userdata/system/99-nvidia.conf" ] && [ -e "$log_file" ] && [ -f "$switchres_backup" ] && [ -f "$nvidia_backup" ]; then
    echo "99-nvidia.conf, switchres.ini backup, and log file exist. Skipping backup."
elif [ -f "/userdata/system/99-nvidia.conf" ]; then
    # Backup 99-nvidia.conf and switchres.ini files 
    install -D -m 0755 /etc/switchres.ini "$switchres_backup"
    install -D -m 0644 /userdata/system/99-nvidia.conf "$nvidia_backup"
    # Create the log file
    touch "$log_file"
else
    # Call the function to make the boot partition writable
    making_boot_writable
    
    # Check if the log file exists
    if [ -e "$log_file" ] && [ -f "$switchres_backup" ] && [ -f "$syslinux_main_backup" ] && [ -f "$syslinux_sub_backup" ]; then
        echo "Syslinux files and switchres.ini backup already performed."
    else
        echo "Backing up syslinux and switchres.ini files..."

        # Backup syslinux.cfg files and switchres.ini
        install -D -m 0755 /etc/switchres.ini "$switchres_backup"
        install -D -m 0755 /boot/boot/syslinux.cfg "$syslinux_main_backup"
        install -D -m 0755 /boot/boot/syslinux/syslinux.cfg "$syslinux_sub_backup"
        install -D -m 0755 /boot/EFI/syslinux.cfg "$syslinux_efi_backup"
        install -D -m 0755 /boot/EFI/BOOT/syslinux.cfg "$syslinux_efi_boot_backup"
        install -D -m 0755 /boot/EFI/batocera/syslinux.cfg "$syslinux_efi_batocera_backup"

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
refresh_rate=$(echo "$boot_resolution" | sed -n 's/.*@\([0-9][0-9]*\).*/\1/p')

# Check if the Boot Resolution is disallowed
disallowed_resolutions=("800x600@60" "1027x576@50" "1027x576@25" "1024x576@25" "1024x768@25" "1024x768@50")
if [[ " ${disallowed_resolutions[@]} " =~ " $boot_resolution " ]]; then
    dialog --title "Unsupported Resolution" \
           --yesno "Your boot resolution is set for $boot_resolution which is not supported.\nWould you like to run the geometry script using 640x480@60?\n\n640x480@60 (Default Recommended)" 10 60
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

        install -D -m 0755 "$switchres_backup" /etc/switchres.ini
        install -D -m 0644 "$nvidia_backup" /userdata/system/99-nvidia.conf

        echo "99-nvidia.conf & switchres.ini successfully restored."

        # Save overlay so restored /etc/switchres.ini persists after reboot
        saving_overlay_file

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

        install -D -m 0755 "$switchres_backup" /etc/switchres.ini
        install -D -m 0755 "$syslinux_main_backup" /boot/boot/syslinux.cfg
        install -D -m 0755 "$syslinux_sub_backup" /boot/boot/syslinux/syslinux.cfg 
        install -D -m 0755 "$syslinux_efi_backup" /boot/EFI/syslinux.cfg
        install -D -m 0755 "$syslinux_efi_boot_backup" /boot/EFI/BOOT/syslinux.cfg
        install -D -m 0755 "$syslinux_efi_batocera_backup" /boot/EFI/batocera/syslinux.cfg

        echo "Syslinux files restored successfully."

        # Save overlay so restored /etc/switchres.ini persists after reboot
        saving_overlay_file

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


# Dialog to select resolution
while true; do
    choice=$(dialog --title "Resolution Selection" \
                    --clear \
                    --nocancel \
                    --menu "Choose your resolution" 20 80 10 \
                    "640x480@60" "640x480 60Hz (Default Recommended)" \
                    "Restore Files" "Revert changes and restore" \
                    "Quit" "Exit back to ES" \
                    3>&1 1>&2 2>&3)

    case $choice in
        "640x480@60")
            width=640
            height=480
            refresh_rate=60
            break
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
geometry_status=$?

# Check if the output contains "Aborted!"
if [[ $output == *"Aborted!"* ]]; then
    dialog --title "Aborted" \
           --msgbox "Aborted! No changes made to switchres.ini." 10 40
    clear_terminal
fi

# Extract the final crt_range value from the output (POSIX-safe)
crt_range_value="$(printf "%s
" "$output" | awk -F': ' '/^[[:space:]]*Final crt_range:/ {print $2; found=1; exit} END{ if(!found) exit 1 }')"

# Fallback extraction if above fails
if [ -z "$crt_range_value" ]; then
    crt_range_value="$(printf "%s
" "$output" | awk '
        /Final[[:space:]]+crt_range[:=]/ {val=$0}
        /crt_range[[:space:]]*[:=]/      {val=$0}
        END{
            sub(/^.*(Final[[:space:]]+)?crt_range[:=][[:space:]]*/,"",val);
            gsub(/[[:space:]]+$/,"",val);
            print val
        }')"
fi

# Stop if geometry did not produce a valid crt_range.
# This prevents writing an empty crt_range0 line to switchres.ini.
if [ $geometry_status -ne 0 ] || [ -z "$crt_range_value" ]; then
    dialog --title "Geometry Error" \
           --msgbox "The geometry tool did not return a valid crt_range. No changes were written to switchres.ini." 10 60
    clear_terminal
fi

swini="/etc/switchres.ini"
[ -f "$swini" ] || touch "$swini"

# Atomically rewrite switchres.ini keeping all other content:
awk -v newrange="$crt_range_value" '
BEGIN {
    seen_monitor=0; seen_crt0=0;
}
{
    # Replace the first monitor line with the canonical "monitor custom"
    if (!seen_monitor && $0 ~ /^[[:space:]]*monitor[[:space:]]+/) {
        print "     monitor                   custom";
        seen_monitor=1;
        next;
    }
    # Replace the first crt_range0 line with the new range
    if (!seen_crt0 && $0 ~ /^[[:space:]]*crt_range0[[:space:]]+/) {
        print "    crt_range0              " newrange;
        seen_crt0=1;
        next;
    }
    # Otherwise pass through unchanged
    print $0;
}
END {
    if (!seen_monitor) print "     monitor                   custom";
    if (!seen_crt0)   print "    crt_range0              " newrange;
}' "$swini" > "${swini}.tmp" && mv "${swini}.tmp" "$swini"

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

    if [ -z "$H_RES_EDID" ] || [ -z "$V_RES_EDID" ] || [ -z "$FREQ" ]; then
        dialog --title "Boot Resolution Error" \
               --msgbox "Could not read a valid Boot Resolution from /userdata/system/logs/BootRes.log. No EDID or NVIDIA modeline changes were made." 10 70
        clear_terminal
    fi

    # Adjust width component only.
    # Keep width and height as separate values for switchres.
    H_RES_EDID=$(( H_RES_EDID + 1 ))

    # Run switchres and capture the first generated Modeline.
    # Use /etc/switchres.ini explicitly so the newly written crt_range is used.
    switchres_output=$(switchres "$H_RES_EDID" "$V_RES_EDID" "$FREQ" -f "${H_RES_EDID}x${V_RES_EDID}@${FREQ}" -i "$swini" -c | awk '/Modeline/ { sub(/^[[:space:]]*Switchres:[[:space:]]*/, ""); print; exit }')

    # Remove leading whitespace and strip SwitchRes suffix from the mode name, if present.
    switchres_output=$(printf "%s\n" "$switchres_output" | sed 's/^[[:space:]]*//; s/\(Modeline[[:space:]]*"[^_"]*\)_[^"]*"/\1"/')

    if [ -z "$switchres_output" ]; then
        dialog --title "SwitchRes Error" \
               --msgbox "SwitchRes did not return a Modeline for the NVIDIA configuration. 99-nvidia.conf was not modified." 10 60
        clear_terminal
    fi

    # Prompt the user if they want to edit the existing 99-nvidia.conf file
    dialog --title "99-nvidia.conf Found" \
           --yesno "99-nvidia.conf file is found.\nDo you want to edit it?" 10 40
    response=$?
    case $response in
        0)  # User selected Yes, so proceed with editing
            # Replace the first existing Modeline safely.
            # If no Modeline exists, append the generated one.
            tmp_nvidia_conf=$(mktemp /tmp/99-nvidia.conf.XXXXXX)
            awk -v newline="$switchres_output" '
                /^[[:space:]]*Modeline[[:space:]]*"/ && !done { print newline; done=1; next }
                { print }
                END { if (!done) print newline }
            ' /userdata/system/99-nvidia.conf > "$tmp_nvidia_conf" && mv "$tmp_nvidia_conf" /userdata/system/99-nvidia.conf

			dialog --title "99-nvidia.conf Updated" \
                   --msgbox "99-nvidia.conf updated successfully. The overlay will now be saved so switchres.ini persists after reboot." 10 60

            # Save overlay so /etc/switchres.ini persists after reboot on NVIDIA setups
            saving_overlay_file
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

    if [ -z "$H_RES_EDID" ] || [ -z "$V_RES_EDID" ] || [ -z "$FREQ" ]; then
        dialog --title "Boot Resolution Error" \
               --msgbox "Could not read a valid Boot Resolution from /userdata/system/logs/BootRes.log. No EDID or NVIDIA modeline changes were made." 10 70
        clear_terminal
    fi

    # Adjust width component only.
    # Keep width and height as separate values for switchres.
    H_RES_EDID=$(( H_RES_EDID + 1 ))

    # Generate the EDID file using switchres in a clean temporary directory.
    # This avoids accidentally reusing an old .bin file from the current directory.
    edid_workdir=$(mktemp -d /tmp/geometry-edid.XXXXXX)
    (
        cd "$edid_workdir" || exit 1
        switchres "$H_RES_EDID" "$V_RES_EDID" "$FREQ" -f "${H_RES_EDID}x${V_RES_EDID}@${FREQ}" -i "$swini" -e
    )

    # Identify the generated EDID file
    edid_file=$(find "$edid_workdir" -maxdepth 1 -name "*.bin" -print -quit)

    # If an EDID file is found, ask the user if they want to overwrite it
    if [ -f "$edid_file" ]; then
        dialog --title "EDID File Found" \
               --yesno "EDID file named 'custom.bin' is found.\nDo you want to overwrite it?" 10 40
        response=$?
        case $response in
            0)  # User selected Yes, so proceed with overwriting
                mv "$edid_file" "$edid_workdir/custom.bin"
                if ! install -D -m 0644 "$edid_workdir/custom.bin" /lib/firmware/edid/custom.bin; then
                    rm -rf "$edid_workdir"
                    dialog --title "EDID Error" \
                           --msgbox "Could not install custom.bin. Boot configuration was not changed." 10 60
                    clear_terminal
                fi
                rm -rf "$edid_workdir"
                if ! geometry_finalize_edid_boot custom.bin; then
                    dialog --title "EDID Error" \
                           --msgbox "custom.bin was written but boot and overlay are out of sync.\nDo not reboot until you run Restore in Geometry or reinstall the CRT boot EDID." 12 70
                    clear_terminal
                fi
                dialog --title "EDID File Generated" \
                       --msgbox "EDID custom.bin, boot, and overlay saved.\nReboot when ready." 10 50
                ;;
            1|255)
                rm -rf "$edid_workdir"
                geometry_revert_switchres_monitor "${monitor_type:-generic_15}"
                fallback_bin="${monitor_type:-generic_15}.bin"
                if [ ! -f "/lib/firmware/edid/${fallback_bin}" ]; then
                    dialog --title "EDID Warning" \
                           --msgbox "EDID not overwritten. Keeping ${fallback_bin}, but that file is missing on disk.\nDo not reboot until the install EDID is restored." 12 70
                    clear_terminal
                fi
                if ! geometry_finalize_edid_boot "$fallback_bin"; then
                    dialog --title "EDID Warning" \
                           --msgbox "Timing saved in switchres.ini, but boot could not be aligned with ${fallback_bin}.\nDo not reboot until you restore or run Geometry again." 12 70
                    clear_terminal
                fi
                dialog --title "EDID Not Overwritten" \
                       --msgbox "Custom timing kept. Boot still uses ${fallback_bin}.\nOverlay saved; safe to reboot." 10 55
                clear_terminal
                ;;
        esac
    else
        rm -rf "$edid_workdir"
        dialog --title "EDID File Not Found" \
               --msgbox "Failed to find generated EDID file. Syslinux EDID references were not changed." 10 60
        clear_terminal
    fi

    clear
fi

