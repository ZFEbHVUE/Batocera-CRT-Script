#!/bin/bash

#######################################################################################
##                               Output Detection Script Start                       ##
#######################################################################################

# Enable testing mode (set to "true" for testing, "false" for real detection)
TEST_MODE=false

# Function to get the count of connected outputs from xrandr
function get_connected_output_count {
    if [ "$TEST_MODE" == "true" ]; then
        echo 2  # Simulate more than one connected output
    else
        export DISPLAY=:0
        xrandr --listmonitors | awk '/\+/ {count++} END {print count}'
    fi
}

# Check the number of connected outputs
CONNECTED_OUTPUTS=$(get_connected_output_count)

# If more than one output is detected
if [ "$CONNECTED_OUTPUTS" -gt 1 ]; then
    # Display a warning message using dialog with a larger box
    dialog --title "Warning!" \
           --msgbox "*************************************************\n\
\nWARNING: More than one input has been detected!\n\n\
Disconnect all outputs except the one you intend to use for outputting to your CRT.\n\
Then restart the script and try again.\n\
*************************************************" \
           15 60
    clear
    exit 1
fi

# If only one output is connected, proceed with the rest of the script
echo "Only one output detected. Proceeding with configuration..."

#######################################################################################
##                               Output Detection Script End                         ##
#######################################################################################

#######################################################################################
##                       10-monitor.conf Output Detection Script Start               ##
#######################################################################################

# File path to check
file_path="/etc/X11/xorg.conf.d/10-monitor.conf"

# Function to show dialog and handle renaming
check_and_rename_file() {
    # Get the current timestamp in the desired format
    timestamp=$(date +"%Y.%m.%d,%H.%M.%S")

    # Rephrased text for the dialog box
    message="The script has detected that this setup script has already been run once.\nDuring the setup, the script disables all display outputs except the connected one.\nTo proceed, the existing configuration file has been backed up and renamed to avoid conflicts."

    # Show the dialog
    dialog --title "Existing Configuration Detected" \
           --backtitle "Monitor Configuration Setup" \
           --ok-label "Ok to Continue" \
           --cancel-label "Cancel to Exit" \
           --msgbox "$message" 10 60

    # Check if the user pressed OK
    if [ $? -eq 0 ]; then
        # Rename the file with the timestamp
        new_file_path="${file_path}.${timestamp}"
        mv "$file_path" "$new_file_path"

        # Set file permissions to 000
        chmod 000 "$new_file_path"

        echo "File renamed to: $new_file_path"

        # Execute batocera-save-overlay and reboot
        dialog --title "Rebooting System" \
               --msgbox "Rebooting Batocera to apply changes. Please run the script again after the reboot." 8 50
        batocera-save-overlay
        reboot
    else
        echo "User chose to exit. Exiting script."
        exit 1
    fi
}

# Main script logic
if [ -f "$file_path" ]; then
    check_and_rename_file
fi

# Continue with the rest of the script here
echo "Proceeding with the script..."

#######################################################################################
##                               10-monitor.conf Detection Script End                ##
#######################################################################################

# Set terminal type and language locale
export TERM=xterm-256color
export LANG=C

# Path to the flag file
FLAG_FILE="/userdata/system/Batocera-CRT-Script/backup.file"

CONFIG_FILE="/etc/X11/xorg.conf.d/10-monitor.conf"

# Function to detect connected displays from /sys/class/drm/*/status
function get_connected_drm_display {
    local valid_card=$(basename $(dirname $(grep -E -l "^connected" /sys/class/drm/*/status)) | sed -e "s,card0-,,")
    echo "$valid_card"
}

# Function to detect connected display from xrandr
function get_connected_xrandr_display {
    export DISPLAY=:0
    local valid_card=$(xrandr --listmonitors | awk '/\+/ {print $NF}')
    echo "$valid_card"
}

# Function to create the flag file
create_flag_file() {
    touch "$FLAG_FILE"
}

# Function to perform backup actions if the flag file doesn't exist
perform_backup_once() {
    if [ ! -f "$FLAG_FILE" ]; then
        # Perform backup actions
        echo "Performing initial backup..."
        
        install -D -m 0644 /userdata/system/batocera.conf /userdata/system/Batocera-CRT-Script/backup/userdata/system/batocera.conf
        install -D -m 0755 /usr/bin/batocera-resolution /userdata/system/Batocera-CRT-Script/backup/usr/bin/batocera-resolution.backup
        install -D -m 0755 /usr/bin/emulationstation-standalone /userdata/system/Batocera-CRT-Script/backup/usr/bin/emulationstation-standalone.backup
        install -D -m 0755 /usr/bin/retroarch /userdata/system/Batocera-CRT-Script/backup/usr/bin/retroarch.backup
        install -D -m 0755 /usr/lib/python3.11/site-packages/configgen/emulatorlauncher.py /userdata/system/Batocera-CRT-Script/backup/usr/lib/python3.11/site-packages/configgen/emulatorlauncher.py.backup
        install -D -m 0644 /usr/lib/python3.11/site-packages/configgen/utils/videoMode.py /userdata/system/Batocera-CRT-Script/backup/usr/lib/python3.11/site-packages/configgen/utils/videoMode.py.backup
        install -D -m 0755 /boot/batocera-boot.conf /userdata/system/Batocera-CRT-Script/backup/boot/batocera-boot.conf.backup
        install -D -m 0755 /boot/boot/syslinux.cfg /userdata/system/Batocera-CRT-Script/backup/boot/boot/syslinux.cfg.backup
        install -D -m 0755 /boot/boot/syslinux/syslinux.cfg /userdata/system/Batocera-CRT-Script/backup/boot/boot/syslinux/syslinux.cfg.backup
        install -D -m 0755 /boot/EFI/syslinux.cfg /userdata/system/Batocera-CRT-Script/backup/boot/EFI/syslinux.cfg.backup
        install -D -m 0755 /boot/EFI/batocera/syslinux.cfg /userdata/system/Batocera-CRT-Script/backup/boot/EFI/batocera/syslinux.cfg.backup

        # Create the flag file after backup
        create_flag_file
    fi
}

# Function to check if the flag file exists and prompt the user for restore or install
check_flag_file() {
    if [ -f "$FLAG_FILE" ]; then
        # Show menu with options to Install, Restore, or Quit
        choice=$(dialog --title "Batocera CRT Script Options" \
                        --clear \
                        --nocancel \
                        --menu "Choose an option:" 15 60 3 \
                        "Install" "Start Script Install" \
                        "Restore" "Restore files" \
                        "Quit" "Exit back to terminal" \
                        3>&1 1>&2 2>&3)

        case $choice in
            "Install")
                # User chose Install, proceed without running the restore script
                clear
                echo "Starting script installation..."
                ;;
            "Restore")
                # User chose Restore, run the restore script
                clear
                echo "#######################################################################"
                echo "##                                                                 ##"
                echo "##             This will restore files modified by the script      ##"
                echo "##             Press Enter to Continue                             ##"
                echo "##             Exit with Pause/Break key                           ##"
                echo "##             The system will reboot                              ##"
                echo "#######################################################################"
                read

                # Make boot writable
                mount -o remount,rw /boot

                # Restore files from backup
                install -D -m 0644 /userdata/system/Batocera-CRT-Script/backup/userdata/system/batocera.conf /userdata/system/batocera.conf
                install -D -m 0755 /userdata/system/Batocera-CRT-Script/backup/usr/bin/batocera-resolution.backup /usr/bin/batocera-resolution
                install -D -m 0755 /userdata/system/Batocera-CRT-Script/backup/usr/bin/emulationstation-standalone.backup /usr/bin/emulationstation-standalone
                install -D -m 0755 /userdata/system/Batocera-CRT-Script/backup/usr/bin/retroarch.backup /usr/bin/retroarch
                install -D -m 0755 /userdata/system/Batocera-CRT-Script/backup/usr/lib/python3.11/site-packages/configgen/emulatorlauncher.py.backup /usr/lib/python3.11/site-packages/configgen/emulatorlauncher.py
                install -D -m 0644 /userdata/system/Batocera-CRT-Script/backup/usr/lib/python3.11/site-packages/configgen/utils/videoMode.py.backup /usr/lib/python3.11/site-packages/configgen/utils/videoMode.py
                install -D -m 0755 /userdata/system/Batocera-CRT-Script/backup/boot/batocera-boot.conf.backup /boot/batocera-boot.conf
                install -D -m 0755 /userdata/system/Batocera-CRT-Script/backup/boot/boot/syslinux.cfg.backup /boot/boot/syslinux.cfg
                install -D -m 0755 /userdata/system/Batocera-CRT-Script/backup/boot/boot/syslinux/syslinux.cfg.backup /boot/boot/syslinux/syslinux.cfg
                install -D -m 0755 /userdata/system/Batocera-CRT-Script/backup/boot/EFI/syslinux.cfg.backup /boot/EFI/syslinux.cfg
                install -D -m 0755 /userdata/system/Batocera-CRT-Script/backup/boot/EFI/batocera/syslinux.cfg.backup /boot/EFI/batocera/syslinux.cfg

                clear
                batocera-save-overlay
                reboot
                ;;
            "Quit")
                # User chose to quit
                clear
                echo "Exiting back to terminal."
                exit 0
                ;;
        esac
    fi
}

# Run backup once if flag file does not exist
perform_backup_once

# Call the function to check if the flag file exists and prompt the user for restore or install
check_flag_file

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[1;34m'
NOCOLOR='\033[0m'


BOOT_RESOLUTION=1
BOOT_RESOLUTION_ES=1
ZFEbHVUE=1


clear
echo "[$(date +"%H:%M:%S")]: BUILD_15KHz_Batocera START" > /userdata/system/logs/BUILD_15KHz_Batocera.log



echo "#######################################################################"
echo "##                                                                   ##"
echo "##                         -FIRST OVER ALL-                          ##"
echo "##                                                                   ##"
echo "##                WE WANT TO DEDICACE THIS VERSION TO                ##"
echo "##						                     ##"
echo "##                      SERGI CLARA ( PSAKHIS )                      ##"
echo "##                               OF                                  ##"
echo "##                          GROOVYARCADE                             ##"
echo "##                                                                   ##"
echo "##       HE DIED THE 9TH OF OCTOBER 2024, ON A BICYCLE ACCIDENT      ##"
echo "##                       HE WAS 44 YEARS OLD                         ##"
echo "##                                                                   ##"
echo "##       HE WORKED ON GROOVY_MISTER / GUNCON2 / RETROARCH / ....     ##"
echo "##                                                                   ##"
echo "##	    WE SEND CONDOLENCES TO HIS FAMILY AND FRIENDS            ##"
echo "##                                                                   ##"
echo "##                 WE CONTINUE WITH OUR WORK FOR HIM                 ##"
echo "##                                                                   ##"
echo "##                           REST IN PEACE                           ##"
echo "##                                                                   ##"
echo "#######################################################################"
read
clear

echo "#######################################################################"
echo "##                                                                   ##"
echo "##                15KHz BATOCERA V32-V36 CONFIGURATION               ##"
echo "##                                                                   ##"
echo "## RION(15KHz master) MYZAR(Nvidia) ZFEbHVUE(main coder and Tester)  ##"
echo "##                                                                   ##"
echo "##                            19/11/2022                             ##"
echo "##                                                                   ##"
echo "##          BEFORE USING THE SCRIPT READ THE FOLLOWING TEXT          ##"
echo "##                                                                   ##"
echo "##              !! USE THIS SCRIPT ON YOUR OWN RISK !!               ##"
echo "##                                                                   ##"
echo "##        AUTHORS OF THIS SCRIPT WILL NOT BE HELD RESPONSIBLE        ##"
echo "##                     FOR ANY DAMMAGES YOU GET                      ##"
echo "##                                                                   ##"
echo "##        YOU MUST HAVE READ THE 15KHz CRT BATOCERA WIKI PAGE        ##"
echo "##        https://wiki.batocera.org/batocera-and-crt?s[]=crt         ##"
echo "##                                                                   ##"
echo "##                 THIS SCRIPT WORKS ON A LCD SCREEN                 ##"
echo "##           (ALSO IN 15KHz CRT IF YOU ARE ALREADY IN 15)            ##"
echo "##                                                                   ##"
echo "##                                                                   ##"
echo "##         YOU NEED TO HAVE RIGHT CONNECTION FOR 15KHz CRT           ##"
echo "##   AND SOME PROTECTIONS FOR YOUR MONITOR AGAINST BAD FREQUENCIES   ##"
echo "##                                                                   ##"
echo "##                   THE SCRIPT IS OPEN SOURCE                       ##"
echo "##           YOU CAN MODIFY IT / IMPROVE IT / REPORT BUGS            ##"
echo "##                                                                   ##"1
echo "##          IF YOU ARE OK WITH THESE CONDITIONS TYPE ENTER           ##"
echo "##                              AND ...                              ##"
echo "##                    HAVE LOTS OF RETRO FUN !!!                     ##"
echo "##                                                                   ##"
echo "## GREETING TO ALL RETRO DEVELOPERS !! (EMULATOR/DISTRIB/FRONTEND...)##"
echo "##                     AND ALL RETRO GAMERS !!                       ##"
echo "##                                                                   ##"
echo "##                                                                   ##"
echo "##                       ==  Cards Tested  ==                        ##"
echo "##                                                                   ##"
echo "##   AMD/ATI:                                                        ##"
echo "##   R7 350x with DVI-I and Display-Port                             ##"
echo "##   R9 280x with DVI-I and Display-Port                             ##"
echo "##                                                                   ##"
echo "##   Intel: display-port and VGA (Optiplex 790/7010                  ##"
echo "##        (VGA works somewhat on)                                    ##"
echo "##                                                                   ##"
echo "##  Nvidia:                                                          ##"
echo "##  8400GS(Tesla)  DVI-I/HDMI/VGA (NOUVEAU)                          ##"
echo "##  Quadro K600(Kelper) DVI-I/(Diplay-Port)  (Nvidia-Driver/Nouveau) ##"
echo "##  GTX980(Maxwell) DVI-I/HDMI/(Diplay-Port) (Nvidia-Driver/Nouveau) ##"
echo "##  GTX1050ti(Pascal) HDMI/(Diplay-Port)     (Nvidia-Driver/Nouveau) ##"
echo "##  GTX1650(turing) (HDMI/Display-Port) Bad 15KHz with only 240p     ##"
echo "##  All display-Port give only 240p with Bad 15KHz                   ##"
echo "##                                                                   ##"
echo "#######################################################################"
echo ""
echo -n -e "                       PRESS ${BLUE}ENTER${NOCOLOR} TO START "
read 
clear

version_Batocera=$(batocera-es-swissknife  --version)
echo "Version batocera = $version_Batocera" >> /userdata/system/logs/BUILD_15KHz_Batocera.log
case $version_Batocera in
        39*)
		echo "Version 39"
		Version_of_batocera="v39"
		verion=39
	;;
	40*)
		echo "Version 40 dev"
		Version_of_batocera="v40"
		verion=40
		;;
	41*)
		echo "Version 41 dev"
		Version_of_batocera="v41"
		verion=41

	;;
	*)
		echo "unknown version"
		exit 1
	;;
esac

echo "#######################################################################"
echo "##                         CARDS INFORMATION                         ##"
echo "#######################################################################"
j=0
for p in /sys/class/drm/card? ; do
	id=$(basename `readlink -f $p/device`)
	temp=$(lspci -mms $id | cut -d '"' -f4,6)
	name_card[$j]="$temp"
	j=`expr $j + 1`
done
echo ""
for var in "${!name_card[@]}" ; do echo "	$((var+1)) : ${name_card[$var]}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log; done
if [[ "$var" -gt 0 ]] ; then
	echo ""
	echo "#######################################################################"
	echo "##                                                                   ##"
	echo "##                Make your choice for graphic card                  ##" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
	echo "##                                                                   ##"
	echo "#######################################################################"
	echo -n "                                  "
	read card_choice
	while [[ ! ${card_choice} =~ ^[1-$((var+1))]$ ]] && [[ "$card_choice" != "" ]] ; do
		echo -n "Select option 1 to $((var+1)):" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
		read card_choice
	done
	selected_card=${name_card[$card_choice-1]}
else
	selected_card=${temp}
fi
###############################################################
##    TYPE OF GRAPHIC CARD
###############################################################
Drivers_Nvidia_CHOICE="NONE"

case $selected_card in
	*[Nn][Vv][Ii][Dd][Ii][Aa]*)

		TYPE_OF_CARD="NVIDIA"

		if [ ! -f "/userdata/system/logs/TYPE_OF_CARD_DRIVERS.info" ]; then
			touch 			/userdata/system/logs/TYPE_OF_CARD_DRIVERS.info
			echo "NVIDIA" >> 	/userdata/system/logs/TYPE_OF_CARD_DRIVERS.info
		else
			rm /userdata/system/logs/TYPE_OF_CARD_DRIVERS.info
			touch 			/userdata/system/logs/TYPE_OF_CARD_DRIVERS.info
			echo "NVIDIA" >> 	/userdata/system/logs/TYPE_OF_CARD_DRIVERS.info
		fi

		echo ""
		echo "#######################################################################"
		echo -e "##                     YOUR VIDEO CARD IS ${GREEN}NVIDIA${NOCOLOR}                     ##"
		echo "#######################################################################"
		echo ""
		echo "#######################################################################"
		echo "##               Do you want Nvidia_drivers or NOUVEAU               ##"
		echo "#######################################################################"
		declare -a Nvidia_drivers_type=( "Nvidia_Drivers" "NOUVEAU" )
		for var in "${!Nvidia_drivers_type[@]}" ; do echo "			$((var+1)) : ${Nvidia_drivers_type[$var]}"; done
		echo "#######################################################################"
		echo "##                         Make your choice                          ##"
		echo "#######################################################################"
		echo -n "                                  "
		read choice_Drivers_Nvidia

		while [[ ! ${choice_Drivers_Nvidia} =~ ^[1-$((var+1))]$ ]] && [[ "$choice_Drivers_Nvidia" = "" ]] ; do
			echo -n "Select option 1 to $((var+1)):"
			read choice_Drivers_Nvidia
		done
		Drivers_Nvidia_CHOICE=${Nvidia_drivers_type[$choice_Drivers_Nvidia-1]}
		echo -e "                    your choice is :  ${GREEN}$Drivers_Nvidia_CHOICE${NOCOLOR}"
		
		echo $Drivers_Nvidia_CHOICE >> 	/userdata/system/logs/TYPE_OF_CARD_DRIVERS.info


		if [ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]; then
			echo ""
			echo "#######################################################################"
			echo "##                  Nvidia drivers version selector                  ##"
			echo "#######################################################################"
			declare -a Name_Nvidia_drivers_version=( "true" "legacy" "legacy390" "legacy340" )
			for var in "${!Name_Nvidia_drivers_version[@]}" ; do echo "			$((var+1)) : ${Name_Nvidia_drivers_version[$var]}"; done
			echo "#######################################################################"
			echo "##                         Make your choice                          ##"
			echo "#######################################################################"
			echo -n "                                  "
			read choice_Name_Drivers_Nvidia
			while [[ ! ${choice_Name_Drivers_Nvidia} =~ ^[1-$((var+1))]$ ]] && [[ "$choice_Name_Drivers_Nvidia" = "" ]] ; do
				echo -n 3"Select option 1 to $((var+1)):"
				read choice_Name_Drivers_Nvidia
			done
			Drivers_Name_Nvidia_CHOICE=${Name_Nvidia_drivers_version[$choice_Name_Drivers_Nvidia-1]}
			echo -e "                    your choice is :  ${GREEN}$Drivers_Name_Nvidia_CHOICE${NOCOLOR}"
	
		fi
	;;
	*[Ii][Nn][Tt][Ee][Ll]*)
		TYPE_OF_CARD="INTEL"
		echo ""
		echo "#######################################################################"
		echo -e "##                     YOUR VIDEO CARD ISAMD/ATI" ${GREEN}INTEL${NOCOLOR}                      ##"
		echo "#######################################################################"

		if [ ! -f "/userdata/system/logs/TYPE_OF_CARD_DRIVERS.info" ]; then
			touch 			/userdata/system/logs/TYPE_OF_CARD_DRIVERS.info
			echo "INTEL" >> 	/userdata/system/logs/TYPE_OF_CARD_DRIVERS.info
		else

			rm /userdata/system/logs/TYPE_OF_CARD_DRIVERS.info
			touch 			/userdata/system/logs/TYPE_OF_CARD_DRIVERS.info
			echo "INTEL" >> 	/userdata/system/logs/TYPE_OF_CARD_DRIVERS.info
		fi

	;;
	*[Aa][Mm][Dd]* | *[Aa][Tt][Ii]*)
		TYPE_OF_CARD="AMD/ATI"

		if [ ! -f "/userdata/system/logs/TYPE_OF_CARD_DRIVERS.info" ]; then
			touch 			/userdata/system/logs/TYPE_OF_CARD_DRIVERS.info
			echo "AMD/ATI" >> 	/userdata/system/logs/TYPE_OF_CARD_DRIVERS.info
		else
			rm /userdata/system/logs/TYPE_OF_CARD_DRIVERS.info
			echo "AMD/ATI" >> 	/userdata/system/logs/TYPE_OF_CARD_DRIVERS.info
			echo "AMD/ATI" >> 	/userdata/system/logs/TYPE_OF_CARD_DRIVERS.info
		fi


		echo ""
		echo "#######################################################################"
		echo -e "##                    YOUR VIDEO CARD IS ${GREEN}AMD/ATI${NOCOLOR}                     ##"
		echo "#######################################################################"
		if [[ "$selected_card" =~ "R9" ]] && [[ "$selected_card" =~ "380" ]]; then
			R9_380="YES"
			echo ""
			echo "#######################################################################"
			echo -e "##                    You have an ${GREEN}ATI R9 380/380x${NOCOLOR}                    ##"
			echo "#######################################################################"
			if grep -q "amdgpu.dc=0" "/boot/EFI/syslinux.cfg" && grep -q "amdgpu.dc=0" "/boot/EFI/BOOT/syslinux.cfg" && grep -q "amdgpu.dc=0" "/boot/boot/syslinux.cfg" && grep -q "amdgpu.dc=0" "/boot/boot/syslinux/syslinux.cfg" ; then
				echo ""
				echo "#######################################################################"
				echo -e "##                   ${GREEN}This card is ready for 15KHz${NOCOLOR}                    ##"
				echo "#######################################################################"
				echo ""
				read
			else
				echo "#######################################################################"
				echo -e "##                 ${RED}This card isn't ready for 15KHz${NOCOLOR}                   ##"
				echo "##                   Need to update syslinux.cfg                     ##"
				echo "#######################################################################"
				echo -n -e "                       PRESS ${BLUE}ENTER${NOCOLOR} TO UPDATE syslinux.cfg "
				term_R9_380_amdgpu="mitigations=off amdgpu.dc=0 "
				read
				mount -o remount, rw /boot
				sed -e "s/mitigations=off/$term_R9_380_amdgpu/g"  /userdata/system/Batocera-CRT-Script/Boot_configs/syslinux.cfg.default > /boot/EFI/syslinux.cfg
				chmod 755 /boot/EFI/syslinux.cfg
				#############################################################################
				## Copy syslinux for EFI and legacy boot
				#############################################################################
				cp /boot/EFI/syslinux.cfg /boot/EFI/BOOT/
				cp /boot/EFI/syslinux.cfg /boot/boot
				cp /boot/EFI/syslinux.cfg /boot/boot/syslinux
				cp /boot/EFI/syslinux.cfg /boot/EFI/batocera/syslinux.cfg
				echo "#######################################################################"
				echo "##           ENTER to reboot and make you card 15KHz ready           ##"
				echo "#######################################################################"

				echo -n -e "                    PRESS ${BLUE}ENTER${NOCOLOR} TO REBOOT "
				read
				reboot
				exit

				fi
				# Define file paths for adding line to EmulationStation configuration
				source_file="/userdata/system/Batocera-CRT-Script/System_configs/R9/v41/es_settings.cfg"
				destination_file="/userdata/system/configs/emulationstation/es_settings.cfg"

				# Check if destination file exists
				if [ ! -f "$destination_file" ]; then
				    # Copy the source file to the destination
				    cp "$source_file" "$destination_file"
				    # Set correct file permissions
				    chmod 0644 "$destination_file"
				else
				    # Ensure "GameTransitionStyle" is at the top, otherwise replace the file
				    if ! grep -q '<string name="GameTransitionStyle" value="instant" />' "$destination_file"; then
				        cp "$source_file" "$destination_file"
				        chmod 0644 "$destination_file"
				    fi
				fi


		else
			R9_380="NO"
			echo ""
			echo "#######################################################################"
			echo -e "##                  ${GREEN}This card is ready for 15KHz${NOCOLOR}                     ##"
			echo "#######################################################################"
			echo -n -e "                       PRESS ${BLUE}ENTER${NOCOLOR} TO CONTINUE "
			read
		fi
echo "here"
		output=$(lspci -vnn | grep -A 12 '[030[02]]' | grep -Ei "vga")
		vendor_name=$(echo "$output" | sed -n -E 's/.*\[(\w+:\w+)\].*/\1/p' | awk -F ':' '{print $1}')
		device_ID=$(echo "$output" | sed -n -E 's/.*\[(\w+:\w+)\].*/\1/p' | awk -F ':' '{print $2}')
		if grep -iq "{0x$vendor_name, 0x$device_ID, .*AMD_IS_APU}" /userdata/system/Batocera-CRT-Script/Cards_detection/list_detection_amd_apu.txt; then
    			AMD_IS_APU=1
			echo ""
			echo "#######################################################################"
			echo -e "##                     YOUR VIDEO CARD IS ${GREEN}AN AMD APU${NOCOLOR}                 ##"
			echo "#######################################################################"
			echo ""

		else
    			AMD_IS_APU=0
			echo ""
			echo "#######################################################################"
			echo -e "##                     YOUR VIDEO CARD IS NOT ${GREEN}AN AMD APU${NOCOLOR}             ##"
			echo "#######################################################################"
			echo ""
		fi

	;;
	*)
		echo "!!!! BE CAREFULL YOUR CARD IS UNKNOWN !!!!"

		exit 1
	;;
esac
echo "	Selected card = $selected_card" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log

#####################################################################################################################################################
#####################################################################################################################################################
ALL_OUTPUTS=($(ls /sys/class/drm/ | grep -E '^card[0-9]+-.*' | sed 's/^card[0-9]*-//'))
CONNECTED_DRM_DISPLAY=$(get_connected_drm_display)
CONNECTED_XRANDR_DISPLAY=$(get_connected_xrandr_display)
#####################################################################################################################################################
#####################################################################################################################################################

# Display connected outputs in /sys/class/drm
echo -e "\nThe connected display in /sys/class/drm\n"
for OUTPUT in "${ALL_OUTPUTS[@]}"; do
    if [ "$OUTPUT" == "$CONNECTED_DRM_DISPLAY" ]; then
        echo -e "${GREEN}${OUTPUT} (Connected Output)${NOCOLOR}"
    else
        echo "$OUTPUT"
    fi
done

# Display xrandr output names and statuses
echo -e "\nThe connected display in xrandr\n"
DISPLAY=:0 xrandr --query | grep -E '^[A-Za-z0-9\-]+.*' | grep -v '^Screen' | while read -r LINE; do
    # Extract the status (connected/disconnected) and trim the output
    STATUS=$(echo "$LINE" | awk '{print $2}')
    NAME=$(echo "$LINE" | awk '{print $1}')
    
    # Format the output by removing 'connected' or 'disconnected'
    FORMATTED_NAME=$(echo "$NAME" | sed -e 's/ connected//g' -e 's/ disconnected//g')
    
    if [ "$STATUS" == "connected" ]; then
        echo -e "${GREEN}${FORMATTED_NAME} connected${NOCOLOR}"
    else
        echo "$FORMATTED_NAME disconnected"
    fi
done

# Prompt user to proceed with disabling other outputs
read -p $'\nAll other displays will now be disabled. Press Enter to continue.'


# Start writing to the configuration file
mkdir -p /etc/X11/xorg.conf.d
tee "$CONFIG_FILE" > /dev/null <<EOF
# Generated by Batocera-CRT-Script
# Disables all outputs except the connected one
EOF

# Variable to track already written identifiers
written_identifiers=()

# Loop through all outputs and configure each
for OUTPUT in "${ALL_OUTPUTS[@]}"; do
    if [ "$OUTPUT" == "$CONNECTED_DRM_DISPLAY" ] || [ "$OUTPUT" == "$CONNECTED_XRANDR_DISPLAY" ]; then
        if [[ ! " ${written_identifiers[@]} " =~ " $OUTPUT " ]]; then
            tee -a "$CONFIG_FILE" > /dev/null <<EOF

Section "Monitor"
    Identifier "$OUTPUT"
EndSection

EOF
            written_identifiers+=("$OUTPUT")
        fi
    else
        if [[ ! " ${written_identifiers[@]} " =~ " $OUTPUT " ]]; then
            tee -a "$CONFIG_FILE" > /dev/null <<EOF

Section "Monitor"
    Identifier "$OUTPUT"
    Option "Ignore" "true"
EndSection

EOF
            written_identifiers+=("$OUTPUT")
        fi
    fi
done



###################################################################################################################################################o#
#####################################################################################################################################################
# Loop through xrandr outputs and add those too
DISPLAY=:0 xrandr --query | grep -E '^[A-Za-z0-9\-]+.*' | grep -v '^Screen' | while read -r LINE; do
    # Extract the status (connected/disconnected) and trim the output
    STATUS=$(echo "$LINE" | awk '{print $2}')
    NAME=$(echo "$LINE" | awk '{print $1}')
    
    # Format the output by removing 'connected' or 'disconnected'
    FORMATTED_NAME=$(echo "$NAME" | sed -e 's/ connected//g' -e 's/ disconnected//g')
    
    # If the output is connected, add to the configuration without the Ignore option
    if [ "$STATUS" == "connected" ]; then
        if [[ ! " ${written_identifiers[@]} " =~ " $FORMATTED_NAME " ]]; then
            tee -a "$CONFIG_FILE" > /dev/null <<EOF

Section "Monitor"
    Identifier "$FORMATTED_NAME"
EndSection

EOF
            written_identifiers+=("$FORMATTED_NAME")
        fi
    else
        if [[ ! " ${written_identifiers[@]} " =~ " $FORMATTED_NAME " ]]; then
            tee -a "$CONFIG_FILE" > /dev/null <<EOF

Section "Monitor"
    Identifier "$FORMATTED_NAME"
    Option "Ignore" "true"
EndSection

EOF
            written_identifiers+=("$FORMATTED_NAME")
        fi
    fi
done
#####################################################################################################################################################
#####################################################################################################################################################



echo "#######################################################################"
echo "##                       Detected card outputs                       ##"  | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
echo "#######################################################################"
echo ""
j=0; declare -a OutputVideo; for i in `ls /sys/class/drm |grep -E -i "^card.-.*" |sed -e 's/card.-//'`; do OutputVideo[$j]="$i"; j=`expr $j + 1`; done
valid_card=$(basename $(dirname $(grep -E -l "^connected" /sys/class/drm/*/status))|sed -e "s,card0-,,")
for var in "${!OutputVideo[@]}" ; do echo "			$((var+1)) : ${OutputVideo[$var]}"  | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log; done
echo ""
echo "#######################################################################"
echo "##                                                                   ##"
echo -e "##                 your connected output: ${GREEN}$valid_card${NOCOLOR}                     ##"
echo "##                                                                   ##"
echo "##                 Make your choice for 15KHz output                 ##"
echo "##                 or press ENTER for connected one                  ##"
echo "##                                                                   ##"
echo "#######################################################################"
echo -n "                                  "
read video_output_choice
while [[ ! ${video_output_choice} =~ ^[1-$((var+1))]$ ]] && [[ "$video_output_choice" != "" ]] ; do
	echo -n "Select option 1 to $((var+1)):" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
	read video_output_choice
done

if [[ "$video_output_choice" == "" ]]; then
        video_output=$valid_card
else
	video_output=${OutputVideo[$video_output_choice-1]}
fi

echo -e "                    your choice is :${GREEN}  $video_output${NOCOLOR}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log

########################################################################################
#####################              15KHz/25KHz/31KHz                  ##################
########################################################################################
CRT_Freq="15KHz"





########################################################################################
#####################               GENERAL  MONITOR                  ##################
########################################################################################



if [ ! -f "/etc/switchres.ini.bak" ];then
	cp /etc/switchres.ini /etc/switchres.ini.bak
fi

clear
#########################################################################################
declare -a type_of_monitor=( 	"generic_15" "ntsc" "pal" "arcade_15" "arcade_15ex" "arcade_25" "arcade_31" \
				"arcade_15_25" "arcade_15_31" "arcade_15_25_31" "vesa_480" "vesa_600" "vesa_768" "vesa_1024" \
				"pc_31_120" "pc_70_120" "h9110" "polo" "pstar" "k7000" "k7131" "d9200" "d9400" "d9800" \
				"m2929" "m3129" "ms2930" "ms929" "r666b"  )  

categories=(			"Generic CRT standards 15 KHz" "Arcade fixed frequency 15 KHz" "Arcade fixed frequency 25/31KHz" \
	    			"Arcade multisync 15/25/31 KHz" "VESA GTF" "PC monitor 120 Hz" "Hantarex" "Wells Gardner" "Makvision" \
	    			"Wei-Ya" "Nanao" "Rodotron")
#########################################################################################
declare -A monitor_categories
monitor_categories["Generic CRT standards 15 KHz"]="generic_15 ntsc pal"
monitor_categories["Arcade fixed frequency 15 KHz"]="arcade_15 arcade_15ex"
monitor_categories["Arcade fixed frequency 25/31KHz"]="arcade_25 arcade_31"
monitor_categories["Arcade multisync 15/25/31 KHz"]="arcade_15_25 arcade_15_31 arcade_15_25_31"
monitor_categories["VESA GTF"]="vesa_480 vesa_600 vesa_768 vesa_1024"
monitor_categories["PC monitor 120 Hz"]="pc_31_120 pc_70_120"
monitor_categories["Hantarex"]="h9110 polo pstar"
monitor_categories["Wells Gardner"]="k7000 k7131 d9200 d9400 d9800"
monitor_categories["Makvision"]="m2929"
monitor_categories["Wei-Ya"]="m3129"
monitor_categories["Nanao"]="ms2930 ms929"
monitor_categories["Rodotron"]="r666b" 
#########################################################################################
counter=0
echo "#######################################################################"
echo "##                     your type of monitor                          ##"
echo "#######################################################################"

for category in "${categories[@]}"; do
  echo ""	
  echo "	$category :"
  monitors="${monitor_categories[$category]}"
  IFS=" " read -ra monitor_array <<< "$monitors"
  for i in "${!monitor_array[@]}"; do
    echo "						$((counter + i + 1)) : ${monitor_array[i]}"
  done
  counter=$((counter + ${#monitor_array[@]}))
done

# Define the log file path
log_file="/userdata/system/logs/BootRes.log"
echo ""
echo "#######################################################################"
echo "##                 Make your choice for monitor type                 ##"
echo "#######################################################################"
echo -n "                                  "
read monitor_choice
monitor_firmware=${type_of_monitor[$monitor_choice-1]}


IFE=0
Amd_NvidiaND_IntelDP=0
Intel_Nvidia_NOUV=0

if ([ "$TYPE_OF_CARD" == "NVIDIA" ] && [ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]) || ([ "$TYPE_OF_CARD" == "AMD/ATI" ]) || ([ "$TYPE_OF_CARD" == "INTEL" ] && [[ $video_output == *"DP"* ]]); then
  
   # Original matrix strings
    	matrix=("arcade_15 320x240@60 640x480@30 768x576@25" "arcade_15_25 320x240@60 640x480@30 768x576@25 1024x576@25 1024x768@30" "arcade_15_31 320x240@60 640x480@30 768x576@25 1024x576@25 1024x768@30"
            	"arcade_15_25_31 320x240@60 640x480@30 768x576@25 1024x576@25 1024x768@25" "arcade_15ex 320x240@60 640x480@25 768 x576@25"
            	"arcade_25 498x384@60 512x384@60 1024x768@30 1072x800@25" "arcade_31 640x480@60" "d9200 320x240@60 640x480@60 768x576@50 800x600@60 1028x576@50"
            	"d9400 320x240@60 640x480@60 768x576@50 800x600@60 1028x576@50" "d9800 320x240@60 640x480@60 768x576@50 800x600@60 1028x576@50"
            	"generic_15 320x240@60 640x480@30 768x576@25" "h9110 320x240@60 640x480@30 768x576@25 1028x576@25" "k7000 320x240@60 640x480@30 768x576@25 1028x576@25"
            	"k7131 320x240@60 640x480@30 768x576@25 1028x576@25" "m2929 640x480@60 768x576@50 800x600@60 1028x576@50" "m3129 320x240@60 640x480@60 768x576@25 1028x576@25"
            	"ms2930 320x240@60 640x480@60 768x576@25 1028x576@25" "ms929 320x240@60 640x480@60 768x576@25 1028x576@25" "ntsc 320x240@60 640x480@30"
            	"pal 320x240@60 640x480@60 768x576@25 1028x576@25" "pc_31_120 320x240@60 640x480@60" "pc_70_120 320x240@60 640x480@60 768x576@50 800x600@60 1024x576@25 1024x768@50"
            	"polo 320x240@60 640x480@60 768x576@25 1024x576@25" "pstar 320x240@60 640x480@60 1024x768@25" "r666b 320x240@60 640x480@60 768x576@25 1024x576@25"
            	"vesa_480 640x480@60 768x576@50" "vesa_600 640x480@60 768x576@50 800x600@60 1024x576@50" "vesa_768 640x480@60 768x576@50 800x600@60 1024x576@50"
            	"vesa_1024 640x480@60 768x576@50 800x600@60 1024x576@50 1024x768@50")
 
 
    if [ "$TYPE_OF_CARD" == "AMD/ATI" ] && [ "$AMD_IS_APU" == 1 ]; then
        IFE=1
    else
        IFE=0
    fi
    Amd_NvidiaND_IntelDP=1
else
    # Original matrix strings
     	matrix=("arcade_15 1280x240@60 1280x480@30 1280x576@25" "arcade_15_25 1280x240@60 1280x480@30" "arcade_15_31 1280x240@60 1280x480@30" "arcade_15_25_31 1280x240@60 1280x480@30"
            	"arcade_15ex 1280x240@60 1280x480@30 1280281280281280281280281x576@25" "arcade_25 1280x768@30 1280x800@25" "arcade_31 1280x480@60" "d9200 1280x240@60 1280x480@60" "d9400 1280x240@60 1280x480@60"
            	"d9800 1280x240@60 1280x480@60" "generic_15 1280x240@60 1280x480@30 1280x576@25" "h9110 1280x240@60 1280x480@30" "k7000 1280x240@60 1280x480@30" "k7131 1280x240@60 1280x480@30"
            	"m2929 1280x480@60" "m3129 1280x240@60 1280x480@60" "ms2930 1280x240@60 1280x480@60" "ms929 1280x240@60 1280x480@60" "ntsc 1280x240@60 1280x480@60" "pal 1280x240@60 1280x480@60"
            	"pc_31_120 1280x240@60 1280x480@60" "pc_70_120 1280x240@60 1280x480@60"  "polo 1280x240@60 1280x480@60" "pstar 1280x240@60 1280x480@60" "r666b 1280x240@60 1280x480@60"
            	"vesa_480 1280x480@60" "vesa_600 1280x480@60" "vesa_768 1280x480@60" "vesa_1024 1280x480@60")

    Intel_Nvidia_NOUV=1
fi

# Find the line in the matrix that corresponds to the selected monitor firmware
monitor_firmware_info=""
for line in "${matrix[@]}"; do

  if [[ "$line" == "$monitor_firmware"* ]]; then

   monitor_firmware_info="$line"
    break
  fi
done

# If the selected monitor firmware is not found, display an error message
if [ -z "$monitor_firmware_info" ]; then
  echo "monitor_firmware_info=Monitor firmware not found in the matrix."
  exit 1
fi

# Split the line into an array using space as the delimiter
IFS=' ' read -ra monitor_info <<< "$monitor_firmware_info"

# Display monitor information
echo "	Information for monitor ${monitor_info[0]}:"

# Display resolution options with centered alignment
for ((i = 1; i < ${#monitor_info[@]}; i++)); do
  printf "						%s\n" "$(printf "%2d : %s" $i "${monitor_info[i]}")"
done

echo ""
echo "#######################################################################"
echo "##       Make your choice for the EDID Resolution                    ##"
echo "#######################################################################"
echo -n "                                  "
read EDID_resolution_choice

# Ensure that EDID_resolution_choice is within a valid range
if [[ $EDID_resolution_choice -ge 1 && $EDID_resolution_choice -le ${#monitor_info[@]} ]]; then
  EDID_resolution=${monitor_info[EDID_resolution_choice]}
  echo -e "				Your choice is :  ${GREEN}$EDID_resolution${NOCOLOR}"
else
  echo "Invalid choice. Please select a valid option."
fi

# Log the resolution choice
{
    echo "Monitor Type: $monitor_firmware"
    echo "Boot Resolution: $EDID_resolution"
} > "$log_file"

IFS="x@ " read -r H_RES_EDID V_RES_EDID FREQ_EDID <<< "$EDID_resolution"

################################################################################################################################
##  HERE FOR NVIDIA-DRIVERS (BEFORE THE EDID IN 99-NVIDIA.CONF) : ADD 1 ON H RESOLUTION (EmulationStation) 
##  TO AVOID THE CONFLICT WITH GEOMETRY TOOLS FOR SAME RESOLTION OF ES
################################################################################################################################
if ([ "$TYPE_OF_CARD" == "NVIDIA" ] && [ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]); then
	H_RES_EDID=$((H_RES_EDID+1))
fi
################################################################################################################################

RES_EDID="${H_RES_EDID}x${V_RES_EDID}"
if [ "$FREQ_EDID" == "50" ] || [ "$FREQ_EDID" == "60" ]; then 
	RES_EDID_SCANNING="${H_RES_EDID}x${V_RES_EDID}p"
elif [ "$FREQ_EDID" == "25" ] || [ "$FREQ_EDID" == "30" ]; then
	RES_EDID_SCANNING="${H_RES_EDID}x${V_RES_EDID}i"
else
	echo "problems of frame rate to determine progressif or interlace"
fi	
FORCED_EDID="${H_RES_EDID}x${V_RES_EDID}@${FREQ_EDID}"
Name_monitor_EDID=$monitor_firmware
sed -i "s/.*monitor         .*/        monitor                   $Name_monitor_EDID/" /etc/switchres.ini
DOTCLOCK_MIN_SWITCHRES=0
sed -i "s/.*dotclock_min        .*/    dotclock_min              $DOTCLOCK_MIN_SWITCHRES/" /etc/switchres.ini
sed -i "s/.*interlace_force_even   .*/        interlace_force_even      $IFE/" /etc/switchres.ini

#switchres $H_RES_EDID $V_RES_EDID $FREQ_EDID -f $FORCED_EDID -m $Name_monitor_EDID  -e  #> /dev/null 2>/dev/null
#
switchres $H_RES_EDID $V_RES_EDID $FREQ_EDID -f $FORCED_EDID -i switchres.ini -e  > /dev/null 2>/dev/null
Name_monitor_EDID+=".bin"

if [ ! -d /lib/firmware/edid ]; then
	mkdir /lib/firmware/edid
fi

patch_edid=$(pwd)
cp $patch_edid/$Name_monitor_EDID  /lib/firmware/edid/
chmod 644  /lib/firmware/edid/$Name_monitor_EDID 
rm $patch_edid/$Name_monitor_EDID   

################################################################################################################################
##  HERE FOR OTHER CARDS (AFTER CREATION OF EDID) :  ADD 1 ON H RESOLUTION (EmulationStation) 
##  TO AVOID THE CONFLICT WITH GEOMETRY TOOLS FOR SAME RESOLTION OF ES
################################################################################################################################
if ([ "$TYPE_OF_CARD" == "NVIDIA" ] && [ "$Drivers_Nvidia_CHOICE" == "NOUVEAU" ]) || [ "$TYPE_OF_CARD" == "AMD/ATI" ] || [ "$TYPE_OF_CARD" == "INTEL" ]; then 
	H_RES_EDID=$((H_RES_EDID+1))
fi
################################################################################################################################

#if [ "$TYPE_OF_CARD" == "NVIDIA" ]&&[ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]; then 
MODE=$(switchres $H_RES_EDID $V_RES_EDID $FREQ_EDID -f $FORCED_EDID -i switchres.ini -c ) > /dev/null 2>/dev/null
################################################################################################################################
################################################################################################################################
MODELINE_PARAMETERS=$(echo "$MODE" | sed -n 's/.*Modeline "[^"]*" \([0-9.]\+\) \([0-9 ]\+\) \(.*\)/\1 \2 \3/p')
read -r Pixel_Clock H_res HF_Porch H_Sync HB_Porch V_res VF_Porch V_Sync VB_Porch Inter HSync VSync <<< "$MODELINE_PARAMETERS"
if [[ "$MODELINE_PARAMETERS" == *"interlace"* ]]; then
    Interlace=2
else
    Interlace=1
fi
Frame_Rate=$(echo "$(echo "$(echo "$Pixel_Clock*1000000" | bc -l)/$(($((H_res+$((HB_Porch-H_res))))*$((V_res+$((VB_Porch-V_res))))))" | bc -l)*$Interlace" | bc -l)
Frame_Rate=$(printf "%.2f" $Frame_Rate)
Resolution_es=""es.resolution=""${H_RES_EDID}"x"${V_RES_EDID}"."${Frame_Rate}"000"
################################################################################################################################
###############################################################################################################################
MODELINE_CUSTOM="\"${RES_EDID}\" $(echo "$MODE" | sed -n 's/.*Modeline "[^"]*" \([0-9.]\+\) \([0-9 ]\+\) \(.*\)/\1 \2 \3/p')"
monitor_name_MAME=$monitor_firmware
echo "monitor mame = $monitor_name_MAME"  >> /userdata/system/logs/BUILD_15KHz_Batocera.log
Name_VideoModes="videomodes.conf_"$monitor_firmware
if [ "$Amd_NvidiaND_IntelDP" == "1" ]; then
	cp /userdata/system/Batocera-CRT-Script/System_configs/VideoModes/Amd_NvidiaND_IntelDP/$Name_VideoModes /userdata/system/videomodes.conf
elif [ "$Intel_Nvidia_NOUV" == "1" ]; then
	cp /userdata/system/Batocera-CRT-Script/System_configs/VideoModes/Intel_NvidiaNOUV/$Name_VideoModes /userdata/system/videomodes.conf
else
	echo "Problems"
fi
chmod 644 /userdata/system/videomodes.conf
chmod 644 /userdata/system/videomodes.conf
cp /userdata/system/videomodes.conf /userdata/system/videomodes.conf.bak 
########################################################################################
#####################              BOOT RESOLUTION        ##############################
########################################################################################
boot_resolution="e"
echo "Boot resolution = $boot_resolution" >> /userdata/system/logs/BUILD_15KHz_Batocera.log
################################################################################################################################
#####################              ES RESOLUTION          ######################################################################

################################################################################################################################
#echo "ES_resolution = $ES_resolution" >> /userdata/system/logs/BUILD_15KHz_Batocera.log

################################################################################################################################
#######################################                  ROTATION                   ############################################
################################################################################################################################
echo -n -e "                       PRESS ${BLUE}ENTER${NOCOLOR} TO CONTINUE "
read
clear
echo ""
echo "#######################################################################"
echo "##                          ROTATING SCREEN                          ##"
echo "##                                                                   ##"
echo "##              FORM THE ACTUAL POSITION OF YOUR MONITOR             ##"
echo "##                    WHAT IS THE SENS OF ROTATION                   ##"
echo "##               TO PASS TO HORIZONTAL OR TO VERTICAL                ##"
echo "##                                                                   ##"
echo "##   IF YOU WANT TO PLAY HORIZONTAL OR VERTICAL GAMES ON YOUR        ##"
echo "##   MONITOR WITHOUT ROTATION PUT : NONE                             ##"
echo "##                                                                   ##"
echo "##                          REMEMBER                                 ##"
echo "##                                                                   ##"
echo "##   FOR MAME(Groovymame) IT WORKS FOR ALL HORIZONTAL AND VERTICAL   ##"
echo "##                        GAMES FOR ALL CONFIGURATIONS SCREEN SETUP  ##"
echo "##                                                                   ##"
echo "##   FOR FBNEO:           HORIZONTAL SCREEN:                         ##"
echo "##                        HORIZONTAL GAMES  (NO ROTATION)            ##"
echo "##                        VERTICAL  GAMES   (WITH ROTATION)          ##"
echo "##                        VERTICAL  SCREEN:                          ##"
echo "##                        HORIZONTAL GAMES  (WITH ROTATION)          ##"
echo "##                        VERTICAL  GAMES   (NO ROTATION)            ##"
echo "##                                                                   ##"
echo "##   FOR LIBRETRO:        IT WORKS FOR ALL HORIZONTAL GAMES FOR      ##"
echo "##                        ROTATING SCREEN WITH BUG IN TATE           ##"
echo "##                                                                   ##"
echo "##   FOR STANDALONE:      IT WORKS FOR HORIZONTAL GAMES FOR          ##"
echo "##                        ROTATING SCREEN                            ##"
echo "##                        THERE ARE SOME BUG FOR SOME EMULATORS      ##"
echo "##                        IN TATE (WINDOWS/...)                      ##"
echo "##                                                                   ##"
echo "##   FOR FPINBALL         IT WORKS FOR IN HORIZONTALE AND VERTICALE  ##"
echo "##                        SCREEN                                     ##"
echo "##                                                                   ##"
echo "## ALL THESE THINGS ARE TO PLAY CLASSIC HORIZONTAL GAMES ON VERTICAL ##"
echo "## SCREEN WITH OR WITHOUT ROTATION WITH CLASSIC EMULATORS. REMENBER  ##"
echo "## BY DEFAULT THEY RUN ON HORIZONTAL SCREEN (WITH NO ROTATION)       ##"
echo "##                                                                   ##"
echo "## ONLY GROOVYMAME CAN PLAY HORIZONTAL OR VERTICAL GAMES ON ANY      ##"
echo "## SCREEN POSITION BECAUSE GROOVYMAME CAN DETECT IF THE GAMES ARE    ##"
echo "## HORITONTAL OR VERTCIAL AT THE START OF THE GAME                   ##"
echo "##                                                                   ##"
echo "#######################################################################"
echo ""
declare -a Screen_rotating=( "None" "Clockwise" "Counter-Clockwise" )
for var in "${!Screen_rotating[@]}" ; do echo "			$((var+1)) : ${Screen_rotating[$var]}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log; done
echo ""
echo "#######################################################################"
echo "##       Make your choice for the sens of your rotation screen       ##"  | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
echo "#######################################################################"
echo -n "                                  "
read Screen_rotating_choice
	while [[ ! ${Screen_rotating_choice} =~ ^[1-$((var+1))]$ ]] ; do
		echo -n "Select option 1 to $((var+1)):"
		read Screen_rotating_choice
	done
Rotating_screen=${Screen_rotating[$Screen_rotating_choice-1]}

echo -e "                    Your choice is : ${GREEN} $Rotating_screen${NOCOLOR}"  | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
echo ""
echo "#######################################################################"
echo "##                  EmulationStation ORIENTATION                     ##"
echo "##            MONITOR SETUP (FROM HORIZONTAL POSITION)               ##"
echo "##                                                                   ##"
echo "## HORIZONTAL                     MONITOR  = NORMAL   (0°)           ##"
echo "## VERTICAL   (Counter-Clockwise) MONITOR  = TATE90   (90°)          ##"
echo "## HORIZONTAL (Inverted)          MONITOR  = INVERTED (180°)         ##"
echo "## VERTICAL   (Clockwise)         MONITOR =  TATE270  (-90° or 270°) ##"
echo "##                                                                   ##"
echo "#######################################################################"
echo ""
declare -a ES_orientation=( "NORMAL" "TATE90" "INVERTED" "TATE270" )
if ([ "$TYPE_OF_CARD" == "NVIDIA" ]&&[ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]); then
	declare -a display_rotation=( "normal" "normal" "normal" "normal" )
	declare -a display_mame_rotation=( "normal" "left" "normal" "right" )
	case $Rotating_screen in
		None)
			declare -a display_libretro_rotation=( "normal" "right" "normal" "right" )
			declare -a display_standalone_rotation=( "normal" "normal" "normal" "normal" )
			declare -a display_fbneo_rotation=( "normal" "right" "normal" "right" )
		;;
		Clockwise)
			declare -a display_libretro_rotation=( "normal" "left" "normal" "right")
			declare -a display_standalone_rotation=( "normal" "left" "normal" "left" )
			declare -a display_fbneo_rotation=( "normal" "right" "normal" "right" )

		;;
		Counter-Clockwise)
			declare -a display_libretro_rotation=( "normal" "right" "normal"  "right" )
			declare -a display_standalone_rotation=( "normal" "right" "normal" "right" )
			declare -a display_fbneo_rotation=( "normal" "right" "normal" "right" )
		;;
		*)
			echo "problems of choice of rotation"
		;;
	esac
else
	declare -a display_rotation=( "normal" "right" "inverted" "left" )
	declare -a display_mame_rotation=( "normal" "normal" "inverted" "normal" )
	case $Rotating_screen in
		None)
			declare -a display_libretro_rotation=( "normal" "right" "inverted" "left" )
			declare -a display_standalone_rotation=( "normal" "right" "inverted" "left" )
			declare -a display_fbneo_rotation=( "normal" "inverted" "inverted" "normal" )
		;;
		Clockwise)
			declare -a display_libretro_rotation=( "normal" "normal" "inverted" "inverted" )
			declare -a display_standalone_rotation=( "normal" "normal" "inverted" "inverted" )
			declare -a display_fbneo_rotation=( "normal" "inverted" "inverted" "normal" )
		;;
		Counter-Clockwise)
			declare -a display_libretro_rotation=( "normal" "inverted" "inverted" "normal" )
			declare -a display_standalone_rotation=( "normal" "inverted" "inverted" "normal" )
			declare -a display_fbneo_rotation=( "normal" "inverted" "inverted" "normal" )
		;;
		*)
			echo "problems of choice of rotation"
		;;
	esac
fi
for var in "${!ES_orientation[@]}" ; do echo "			$((var+1)) : ${ES_orientation[$var]}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log; done
echo ""
echo "#######################################################################"
echo "##       Make your choice for the EmulationStation ORIENTATION       ##"
echo "#######################################################################"
echo -n "                                  "
read es_rotation_choice
while [[ ! ${es_rotation_choice} =~ ^[1-$((var+1))]$ ]] ; do
	echo -n "Select option 1 to $((var+1)):"
	read es_rotation_choice
done
ES_rotation=${ES_orientation[$es_rotation_choice-1]}
display_rotate=${display_rotation[$es_rotation_choice-1]}
display_mame_rotate=${display_mame_rotation[$es_rotation_choice-1]}
display_libretro_rotate=${display_libretro_rotation[$es_rotation_choice-1]}
display_standalone_rotate=${display_standalone_rotation[$es_rotation_choice-1]}
display_fbneo_rotate=${display_fbneo_rotation[$es_rotation_choice-1]}

echo -e "                    Your choice is :  ${GREEN}$ES_rotation${NOCOLOR}"  | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log

################################################################################################################################
##########################################      Super-resolutions       ########################################################
################################################################################################################################

super_width_vertical=1920
interlace_vertical=0
dotclock_min_vertical=25

super_width_horizont=1920
interlace_horizont=0
dotclock_min_horizont=25

if [ "$TYPE_OF_CARD" == "AMD/ATI" ]; then
	
	dotclock_min=0	
	dotclock_min_mame=$dotclock_min
	super_width=2560
	super_width_mame=2560 
	drivers_type=AMDGPU
	
	if [ "$R9_380" == "YES" ]; then
		drivers_amd="amdgpu.dc=0"
	else
		drivers_amd=""
	fi
	echo "AMDGPU" >> 	/userdata/system/logs/TYPE_OF_CARD_DRIVERS.info
	
	if [[ "$video_output" == *"DP"* ]]; then
		term_dp="DP"
		term_displayport="DisplayPort"
		video_display=${video_output/$term_dp/$term_displayport}
		nbr=$(sed 's/[^[:digit:]]//g' <<< "${video_output}")
		video_modeline=$term_displayport-$((nbr-1))
	elif [[ $video_output == *"DVI"* ]]; then
		nbr=$(sed 's/[^[:digit:]]//g' <<< "${video_output}")
		video_display=$video_output
	
  		term_DVI=DVI-I
		if [ "$R9_380" == "YES" ]; then
			video_modeline=$term_DVI-$((nbr))
		else
			video_modeline=$term_DVI-$((nbr-1))
		fi	
  
	elif [[ "$video_output" == *"VGA"* ]]; then
		term_VGA=VGA
		nbr=$(sed 's/[^[:digit:]]//g' <<< "${video_output}")
		video_display=$video_output
		video_modeline=$term_VGA-$((nbr-1))
	elif [[ "$video_output" == *"HDMI"* ]] ; then
		term_HDMI=HDMI-A
		nbr=$(sed 's/[^[:digit:]]//g' <<< "${video_output}")
		video_display=$video_output
 		video_modeline=$term_HDMI-$((nbr-1))
		dotclock_min=25.0
		dotclock_min_mame=$dotclock_min
		super_width=3840
		super_width_mame=$super_width
	fi 
 elif [ "$TYPE_OF_CARD" == "INTEL" ]; then
	drivers_amd=""
	if [[ "$video_output" == *"DP"* ]]; then
		term_dp="DP"
		term_displayport="DisplayPort"
		video_display=$video_output 
		nbr=$(sed 's/[^[:digit:]]//g' <<< "${video_output}")
		video_modeline=$term_dp-$((nbr))   
		dotclock_min=0
		dotclock_min_mame=$dotclock_min
		super_width=1920
		super_width_mame=$super_width
	elif [[ "$video_output" == *"VGA"* ]]; then
		term_VGA="VGA"
		nbr=$(sed 's/[^[:digit:]]//g' <<< "${video_output}")
		video_display=$video_output
		video_modeline=$term_VGA-$((nbr))
		dotclock_min=25.0
		dotclock_min_mame=$dotclock_min
		super_width=1920
		super_width_mame=$super_width
	fi
elif [ "$TYPE_OF_CARD" == "NVIDIA" ]; then
	drivers_amd=""
	if [[ "$video_output" == *"DP"* ]]; then
		term_dp="DP"
		term_displayport="DisplayPort"
		video_display=$video_output 
		nbr=$(sed 's/[^[:digit:]]//g' <<< "${video_output}")
		if [ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]; then
			if [ "$Drivers_Name_Nvidia_CHOICE" == "legacy" ]||[ "$Drivers_Name_Nvidia_CHOICE" == "legacy390" ]||[ "$Drivers_Name_Nvidia_CHOICE" == "legacy340" ]; then
				video_modeline=$term_dp-$((nbr)) 
				dotclock_min=0
				dotclock_min_mame=$dotclock_min
				super_width=3840
				super_width_mame=$super_width
			else
				video_modeline=$term_dp-$((nbr-1)) 
				dotclock_min=0
				dotclock_min_mame=$dotclock_min
				super_width=3840
				super_width_mame=$super_width
			fi
		else	
			video_modeline=$term_dp-$((nbr)) 
			dotclock_min=0
			super_width=3840
			super_width_mame=$super_width
		fi
	elif [[ "$video_output" == *"DVI"* ]]; then
		term_DVI=DVI-I
		nbr=$(sed 's/[^[:digit:]]//g' <<< "${video_output}")
		video_display=$video_output
		if [ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]; then
			if [ "$Drivers_Name_Nvidia_CHOICE" == "legacy" ]||[ "$Drivers_Name_Nvidia_CHOICE" == "legacy390" ]||[ "$Drivers_Name_Nvidia_CHOICE" == "legacy340" ]; then
				video_modeline=$term_DVI-$((nbr-1))
				dotclock_min=25
				dotclock_min_mame=$dotclock_min
				super_width=3840
				super_width_mame=$super_width
			else
				video_modeline=$term_DVI-$((nbr-1))
				dotclock_min=0
				dotclock_min_mame=$dotclock_min
				super_width=3840
				super_width_mame=$super_width
			fi
		else
			video_modeline=$term_DVI-$((nbr))
			dotclock_min=25
			dotclock_min_mame=$dotclock_min
			super_width=3840
			super_width_mame=$super_width
		fi
	elif [[ "$video_output" == *"HDMI"* ]] ; then
		term_HDMI=HDMI
		nbr=$(sed 's/[^[:digit:]]//g' <<< "${video_output}")
		video_display=$video_output
		if [ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]; then
			if [ "$Drivers_Name_Nvidia_CHOICE" == "legacy" ]||[ "$Drivers_Name_Nvidia_CHOICE" == "legacy390" ]||[ "$Drivers_Name_Nvidia_CHOICE" == "legacy340" ]; then	
				video_modeline=$term_HDMI-$((nbr-1))
				dotclock_min=25.0
				dotclock_min_mame=$dotclock_min
				super_width=3840
				super_width_mame=$super_width
			else
				video_modeline=$term_HDMI-$((nbr-1))
			 	dotclock_min=25.0
				dotclock_min_mame=$dotclock_min
				super_width=3840
				super_width_mame=$super_width
			fi
		else
			video_modeline=$term_HDMI-$((nbr))
			dotclock_min=25.0
			dotclock_min_mame=$dotclock_min
			super_width=3840
			super_width_mame=$super_width
		fi
	elif [[ "$video_output" == *"VGA"* ]] ; then
		term_VGA=VGA
		nbr=$(sed 's/[^[:digit:]]//g' <<< "${video_output}")
		video_display=$video_output
		if [ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]; then
			if [ "$Drivers_Name_Nvidia_CHOICE" == "legacy" ]||[ "$Drivers_Name_Nvidia_CHOICE" == "legacy390" ]||[ "$Drivers_Name_Nvidia_CHOICE" == "legacy340" ]; then	
				video_modeline=$term_VGA-$((nbr-1))
				dotclock_min=25.0
				dotclock_min_mame=$dotclock_min
				super_width=3840
				super_width_mame=$super_width
			else
				video_modeline=$term_VGA-$((nbr-1))
				dotclock_min=25.0
				dotclock_min_mame=$dotclock_min
				super_widthe=3840
				super_width_mame=$super_width
			fi
		else
			video_modeline=$term_VGA-$((nbr))
			dotclock_min=0.0
			dotclock_min_mame=$dotclock_min
			super_width=3840
			super_width_mame=$super_width
		fi
	fi
fi

if [ "$CRT_Freq" == "31KHz" ]; then
	dotclock_min=25.0
	dotclock_min_mame=$dotclock_min
fi

#######################################################################
###                 Start of ADVANCED CONFIGURATION                ####
#######################################################################
echo -n -e "                       PRESS ${BLUE}ENTER${NOCOLOR} TO CONTINUE "
read
clear
echo "#######################################################################"
echo "##                                                                   ##"
echo "##                      ADVANCED CONFIGURATION                       ##"
echo "##                                                                   ##"
echo "##                     Experimental options for:                     ##"
echo "##                        * minimum dotclock                         ##"
echo "##                        * super-resolution                         ##" 
echo "##                                                                   ##"
echo "##       (If you don't know what this means, just press ENTER)       ##"
echo "##                                                                   ##"
echo "#######################################################################" 
echo ""
declare -a Default_DT_SR_choice=( "YES" "NO" ) 
for var in "${!Default_DT_SR_choice[@]}" ; do echo "			$((var+1)) : ${Default_DT_SR_choice[$var]}"  | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log; done
echo ""
echo "#######################################################################"
echo "##                 Go into advanced configuration ?                  ##"  | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
echo "#######################################################################"
echo -n "                                  "
read choice_DT_SR
while [[ ! ${choice_DT_SR} =~ ^[1-$((var+1))]$ ]] && [[ "$choice_DT_SR" != "" ]] ; do
	echo -n "Select option 1 to $((var+1)) or ENTER to bypass this configuration:"
	read choice_DT_SR
done
if [[ -z "$choice_DT_SR" || $choice_DT_SR = "2" ]] ; then 
	echo "                    your choice is : Don't mess with it, sorry ;)."  | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
else 
	DT_SR_Choice=${Default_DT_SR_choice[$choice_DT_SR-1]}
echo -e "                    your choice is :${GREEN} $DT_SR_Choice ${NOCOLOR}"  | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
fi

if [ "$DT_SR_Choice" == "YES" ] ; then
	echo -n -e "                       PRESS ${BLUE}ENTER${NOCOLOR} TO CONTINUE "
	read
	clear
	echo ""
	echo "#######################################################################"
	echo "##                                                                   ##"
	echo "##                      ADVANCED CONFIGURATION       1/3             ##"  | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
	echo "##                                                                   ##"
	echo "##            Tinker only if you know what you are doing             ##"
	echo "##                 or if you have problems launching                 ##"
	echo "##                  some cores like nes or pcengine                  ##"
	echo "##                          (Black Screen)                           ##"
	echo "##                                                                   ##"
	echo "##              ==     minimum dotclock selector     ==              ##"
	echo "##                                                                   ##"
	echo "##         If you don't know about it or if you want to let          ##"
	echo "##        batocera configure automatically your dotclock_min         ##"
	echo "##                            press ENTER                            ##"
	echo "##                                                                   ##"
	echo "#######################################################################"
	echo ""
	declare -a dcm_selector=( "Low - 0" "Mild - 6" "Medium - 12" "High - 25" "CUSTOM")
	for var in "${!dcm_selector[@]}" ; do echo "			$((var+1)) : ${dcm_selector[$var]}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log; done
	echo ""
	echo "#######################################################################" 
	echo "##               Make your choice for minimum dotclock               ##"5
	echo "#######################################################################"
	echo -n "                                  "
	read dcm
	while [[ ! ${dcm} =~ ^[1-$((var+1))]$ ]] && [[ "$dcm" != "" ]] ; do
		echo -n "Select option 1 to $((var+1)) or ENTER to bypass this configuration:"
		read dcm
	done
	if [ -z "$dcm" ] ; then 
		echo -e "                    your choice is :${GREEN} Batocera default minimum dotclock${NOCOLOR}"  | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
	else 
		echo -e "                    your choice is :${GREEN}  ${dcm_selector[$dcm-1]}${NOCOLOR}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
		case $dcm in
			1) 	dotclock_min=0;;
			2) 	dotclock_min=6;;
			3) 	dotclock_min=12;;
			4) 	dotclock_min=25;;
			5) 	echo "#######################################################################"
				echo "##       Select your custom main dotclock_min: between 0 to 25       ##"
				echo "#######################################################################"
				echo -n "                                  "
				read dotclock_min
				while [[ ! $dotclock_min =~ ^[0-9]+$ || "$dotclock_min" -lt 0 || "$dotclock_min" -gt 25 ]]; do
					echo -n "Enter number between 0 and 25 for dotclock_min: "
					read dotclock_min
				done
				echo -e "                    CUSTOM dotclock_min value = ${GREEN}${dotclock_min}${NOCOLOR}"  | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
			;;
		esac
	fi
	# Check if it was chosen to configurate a particular monitor for M.A.M.E.
	if [ "$monitor_MAME_CHOICE" = "YES" ] ; then
		echo ""
		echo "#######################################################################"
		echo "##                                                                   ##"
		echo "##                      ADVANCED CONFIGURATION       1b/3            ##"  | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
		echo "##                                                                   ##"
		echo "##                         M.A.M.E. MONITOR                          ##"
		echo "##            Tinker only if you know what you are doing             ##"
		echo "##                 or if you have problems launching                 ##"
		echo "##                           M.A.M.E.                                ##"
		echo "##                        (Black Screen)                             ##"
		echo "##                                                                   ##"
		echo "##         ==     M.A.M.E. minimum dotclock selector     ==          ##"
		echo "##                                                                   ##"
		echo "##         If you don't know about it or if you want to let          ##"
		echo "##                 same dotclock_min as main monitor                 ##"
		echo "##                            press ENTER                            ##"
		echo "##                                                                   ##"
		echo "#######################################################################" 
		echo ""
		declare -a dcm_m_selector=( "Low - 0" "Mild - 6" "Medium - 12" "High - 25" "CUSTOM")
		for var in "${!dcm_m_selector[@]}" ; do echo "			$((var+1)) : ${dcm_m_selector[$var]}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log; done
		echo""
		echo "#######################################################################" 
		echo "##            Make your choice for MAME minimum dotclock             ##"
		echo "#######################################################################"
		echo -n "                                  "
		read dcm_m
		while [[ ! ${dcm_m} =~ ^[1-$((var+1))]$ ]] && [[ "$dcm_m" != "" ]] ; do
			echo -n "Select option 1 to $((var+1)) or ENTER to bypass this configuration:"
			read dcm_m
		done
		if [ -z "$dcm_m" ] ; then 
			echo -e "                    your choice is :${GREEN} Same as main monitor ($dotclock_min)${NOCOLOR}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
			dotclock_min_mame=$dotclock_min
		else
			echo -e "                    your choice is :${GREEN}  ${dcm_selector[$dcm_m-1]}${NOCOLOR}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
			case $dcm_m in
				1)	dotclock_min_mame=0;;
				2)	dotclock_min_mame=6;;
				3)	dotclock_min_mame=12;;
				4)	dotclock_min_mame=25;;
				5) 	echo "#######################################################################"
					echo "##       Select your MAME custom dotclock_min: between 0 to 25       ##" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
					echo "#######################################################################"
					echo -n "                                  "
					read dotclock_min_mame
					while [[ ! $dotclock_min_mame =~ ^[0-9]+$ || "$dotclock_min_mame" -lt 0 || "$dotclock_min_mame" -gt 25 ]] ; do
						echo -n "Enter number between 0 and 25 for dotclock_min_mame: "
						read dotclock_min_mame
					done
					echo -e "                    CUSTOM dotclock_min_mame value = ${GREEN}${dotclock_min_mame}${NOCOLOR}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
					;;
			esac
		fi
	fi
	#########################################################################
	##                    super-resolution CONFIG                          ##
	#########################################################################
	echo ""
	echo "#######################################################################"
	echo "##                                                                   ##"
	echo "##                      ADVANCED CONFIGURATION       2/3             ##" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
	echo "##                                                                   ##"
	echo "##                  ==     Super-resolution     ==                   ##"
	echo "##                                                                   ##"
	echo "##        This option sets the value for vertical resolution         ##"
	echo "##             You can set a default maker tested value              ##"
	echo "##        or you can test your own custom one (experimental)         ##"
	echo "##                                                                   ##"
	echo "##                  If you don't know about it or                    ##"
	echo "##                 if you want to let the script                     ##"
	echo "##        set default super-resolution for your graphics card        ##"
	echo "##                            press ENTER                            ##"
	echo "##                                                                   ##"
	echo "#######################################################################"
	echo ""
	declare -a sr_selector=( "1920 - Intel default" "2560 - amd/ati default" "3840 - nvidia default" "CUSTOM (experimental)")
	for var in "${!sr_selector[@]}" ; do echo "			$((var+1)) : ${sr_selector[$var]}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log; done
	echo ""
	echo "#######################################################################"
	echo "##             Make your choice for super-resolution                 ##"
	echo "#######################################################################"
	echo -n "                                  "
	read sr_choice
	while [[ ! ${sr_choice} =~ ^[1-$((var+1))]$ ]] && [[ "$sr_choice" != "" ]] ; do
		echo -n "Select option 1 to $((var+1)) or ENTER to bypass this configuration:"
		read sr_choice
	done
	if [ -z "$sr_choice" ] ; then 
		echo -e "                    your choice is :${GREEN} default super-resolution${NOCOLOR}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
	else
		echo -e "                    your choice is :${GREEN}  ${sr_selector[$sr_choice-1]}${NOCOLOR}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
		case $sr_choice in
			1)	super_width=1920;;
			2)	super_width=2560;;
			3)	super_width=3840;;
			4)	echo "#######################################################################"
				echo "##                Select your custom super_resolution                ##"
				echo "#######################################################################"
				echo -n "                                  "
				read super_width
				while [[ ! $super_width =~ ^[0-9]+$ || "$super_width" -lt 0 ]] ; do
					echo -n "Enter valid number greater than 0 for custom super-resolution:"
					read super_width
				done
				echo -e "                    CUSTOM super-resolution value = ${GREEN}${super_width}${NOCOLOR}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
				;;
		esac
	fi
	if [ "$monitor_MAME_CHOICE" = "YES" ] ; then
		echo ""
		echo "#######################################################################"
		echo "##                                                                   ##"
		echo "##                      ADVANCED CONFIGURATION       2b/3            ##" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
		echo "##                                                                   ##"
		echo "##                ==     MAME Super-resolution     ==                ##"
		echo "##                                                                   ##"
		echo "##        This option sets the value for vertical resolution         ##"
		echo "##             You can set a default maker tested value              ##"
		echo "##        or you can test your own custom one (experimental)         ##"
		echo "##                                                                   ##"
		echo "##                 If you don't know about it or                     ##"
		echo "##                 if you want to let the script                     ##"
		echo "##     set default MAME super-resolution for your graphics card      ##"
		echo "##                            press ENTER    /lib/firmware/edid      ##"
		echo "##                                                                   ##"
		echo "#######################################################################"
		echo ""
		declare -a sr_m_selector=( "1920 - Intel default" "2560 - amd/ati/ default" "3840 - nvidia default" "Same as main monitor" "CUSTOM (experimental)")
		for var in "${!sr_m_selector[@]}" ; do echo "			$((var+1)) : ${sr_m_selector[$var]}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log; done
		echo ""
		echo "#######################################################################"
		echo "##          Make your choice for MAME super-resolution               ##"
		echo "#######################################################################"
		echo -n "                                  "
		read sr_m_choice
		while [[ ! ${sr_m_choice} =~ ^[1-$((var+1))]$ ]] && [[ "$sr_m_choice" != "" ]] ; do
			echo -n "Select option 1 to $((var+1)) or ENTER to bypass this configuration:"
			read sr_m_choice
		done
		if [ -z "$sr_m_choice" ] ; then 
			echo -e "                    your choice is :${GREEN} MAME default super-resolution${NOCOLOR}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
		else
			echo -e "                    your choice is :${GREEN}  ${sr_m_selector[$sr_m_choice-1]}${NOCOLOR}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
			case $sr_m_choice in
				1)	super_width_mame=1920;;
				2)	super_width_mame=2560;;
				3)	super_width_mame=3840;;
				4)	super_width_mame=$super_width;;
				5)	echo "#######################################################################"
					echo "##             Select your custom MAME super_resolution              ##"
					echo "#######################################################################"
					echo -n "                                  "
					read super_width_mame
					while [[ ! $super_width_mame =~ ^[0-9]+$ || "$super_width_mame" -lt 0 ]] ; do
						echo -n "Enter valid number greater than 0 for custom super-resolution"
						read super_width_mame
					done
					echo -e "                    CUSTOM MAME super-resolution value = ${GREEN}${super_width_mame}${NOCOLOR}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
					;;
			esac

		fi
	fi
fi
#######################################################################
###                 Start of usb polling rate config               ####
#######################################################################
echo ""
echo "#######################################################################"
echo "##                                                                   ##"
echo "##                      ADVANCED CONFIGURATION       3/3             ##" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
echo "##                                                                   ##"
echo "##            Tinker only if you know what you are doing.            ##"
echo "##              This configuration can reduce input lag              ##"
echo "##                                                                   ##"
echo "##                        USB FAST POLLING                           ##"
echo "##                                                                   ##"
echo "##         If you don't know about it or if you want to let          ##"
echo "##      batocera configure automatically your USB POLLING RATE       ##"
echo "##                           press ENTER                             ##"
echo "##                                                                   ##"
echo "#######################################################################" 
echo ""
declare -a usb_selector=( "Activate(reduce input lag)" "Keep default" )
for var in "${!usb_selector[@]}" ; do echo "			$((var+1)) : ${usb_selector[$var]}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log; done
echo ""
echo "#######################################################################" 
echo "##               Make your choice for USB POLLING RATE               ##"
echo "#######################################################################"
echo -n "                                  "
read p_rate
	while [[ ! ${p_rate} =~ ^[1-$((var+1))]$ ]] && [[ "$p_rate" != "" ]] ; do
		echo -n "Select option 1 to $((var+1)) or ENTER to bypass this configuration:"
		read p_rate
	done
if [ -z "$p_rate" ] ; then 
	echo -e "                    your choice is :${GREEN} Batocera default usb polling rate${NOCOLOR}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
	polling_rate="usbhid.jspoll=0 xpad.cpoll=0"
elif [ "x$p_rate" != "x0" ] ; then
	echo -e "                    your choice is :${GREEN}  ${usb_selector[$p_rate-1]}${NOCOLOR}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
	case $p_rate in
		1) polling_rate="usbhid.jspoll=1 xpad.cpoll=1";;
		*) polling_rate="usbhid.jspoll=0 xpad.cpoll=0";;
	esac
fi

#############################################################################
## Make the boot writable
#############################################################################
echo "#######################################################################"
echo "##               mount -o remount, rw /boot                          ##" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
echo "#######################################################################"

mount -o remount, rw /boot

#############################################################################
# first time using the script save the batocera-boot.conf batocera-boot.conf.bak
#############################################################################
if [ ! -f "/boot/batocera-boot.conf.bak" ];then
	cp /boot/batocera-boot.conf /boot/batocera-boot.conf.bak
fi

cp /boot/batocera-boot.conf  /boot/batocera-boot.conf.tmp

#############################################################################
# choose #nvidia-driver (NOUVEAU) or nvidia-driver=true (nvidia driver)
#############################################################################
if [ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]; then
	if   [ "$Drivers_Name_Nvidia_CHOICE" == "true" ]; then
		sed -e 's/.*nvidia-driver=.*/nvidia-driver=true/' -e 's/.*amdgpu=.*/#amdgpu=true/' 	/boot/batocera-boot.conf > /boot/batocera-boot.conf.tmp
	elif [ "$Drivers_Name_Nvidia_CHOICE" == "legacy" ]; then
		sed -e 's/.*nvidia-driver=.*/nvidia-driver=legacy/'  -e 's/.*amdgpu=.*/#amdgpu=true/'  	/boot/batocera-boot.conf > /boot/batocera-boot.conf.tmp
	elif [ "$Drivers_Name_Nvidia_CHOICE" == "legacy390" ]; then
		sed -e 's/.*nvidia-driver=.*/nvidia-driver=legacy390/' -e 's/.*amdgpu=.*/#amdgpu=true/' /boot/batocera-boot.conf > /boot/batocera-boot.conf.tmp
        elif [ "$Drivers_Name_Nvidia_CHOICE" == "legacy340" ]; then
		sed -e 's/.*nvidia-driver=.*/nvidia-driver=legacy340/' -e 's/.*amdgpu=.*/#amdgpu=true/' /boot/batocera-boot.conf > /boot/batocera-boot.conf.tmp
	else
		echo "problems of Nvidia driver name"
	fi	
else
	if [ "$Drivers_Nvidia_CHOICE" == "NOUVEAU" ]&&([ "$Version_of_batocera" == "v39" ]||[ "$Version_of_batocera" == "v40" ]||[ "$Version_of_batocera" == "v41" ]); then
		sed -e 's/.*nvidia-driver=.*/nvidia-driver=false/' -e 's/.*amdgpu=.*/#amdgpu=true/' 	 	/boot/batocera-boot.conf > /boot/batocera-boot.conf.tmp
	else
		if [ "$TYPE_OF_CARD" == "AMD/ATI" ]&&([ "$Version_of_batocera" == "v39" ]||[ "$Version_of_batocera" == "v40" ]||[ "$Version_of_batocera" == "v41" ]); then

			if [ "$drivers_type" == "AMDGPU" ]; then
				sed -e 's/.*nvidia-driver=.*/#nvidia-driver=true/' -e 's/.*amdgpu=.*/amdgpu=true/'	/boot/batocera-boot.conf > /boot/batocera-boot.conf.tmp
			else
				sed -e 's/.*nvidia-driver=.*/#nvidia-driver=true/' -e 's/.*amdgpu=.*/amdgpu=false/' 	/boot/batocera-boot.conf > /boot/batocera-boot.conf.tmp
			fi
		else
			sed -e 's/.*nvidia-driver=.*/#nvidia-driver=true/' -e 's/.*amdgpu=.*/#amdgpu=true/' 		/boot/batocera-boot.conf > /boot/batocera-boot.conf.tmp
		fi
	fi
fi



cp /boot/batocera-boot.conf.tmp  /boot/batocera-boot.conf
rm /boot/batocera-boot.conf.tmp 

if [ "$BOOT_RESOLUTION" == "1" ]; then
	sed -i "s/.*es.resolution=.*/$Resolution_es/" 		/boot/batocera-boot.conf
else
	sed -i 's/.*es.resolution=.*/#es.resolution=640x480/' 	/boot/batocera-boot.conf 
fi

if [ "$TYPE_OF_CARD" == "NVIDIA" ]; then
	sed -i "s/.*splash.screen.enabled=.*/splash.screen.enabled=0/" /boot/batocera-boot.conf
else
	sed -i "s/.*splash.screen.enabled=.*/#splash.screen.enabled=0/" /boot/batocera-boot.conf
fi



chmod 755 /boot/batocera-boot.conf

#############################################################################
## Copy of the right syslinux for your write device
#############################################################################
# first time using the script save the syslinux.cfg in syslinux.cfg

if [ ! -f "/boot/EFI/syslinux.cfg.initial" ];then
	cp /boot/EFI/syslinux.cfg /boot/EFI/syslinux.cfg.initial
fi

###  Condition to be reviewed

sed -e "s/\[amdgpu_drivers\]/$drivers_amd/g" -e "s/\[card_output\]/$video_output/g" \
	-e "s/\[monitor\]/$monitor_firmware.bin/g" -e "s/\[card_display\]/$video_display/g" \
	-e "s/\[usb_polling\]/$polling_rate/g" \
	-e "s/\[boot_resolution\]/$boot_resolution/g"  /userdata/system/Batocera-CRT-Script/Boot_configs/syslinux.cfg-generic-Batocera \
	>  /boot/EFI/syslinux.cfg

chmod 755 /boot/EFI/syslinux.cfg

#############################################################################
## Copy syslinux for EFI and legacy boot
#############################################################################

cp /boot/EFI/syslinux.cfg		/boot/EFI/BOOT/
cp /boot/EFI/syslinux.cfg 		/boot/boot/
cp /boot/EFI/syslinux.cfg 		/boot/boot/syslinux/
cp /boot/EFI/syslinux.cfg 		/boot/EFI/batocera/

cp /boot/EFI/syslinux.cfg 		/boot/EFI/syslinux.cfg.bak
cp /boot/EFI/BOOT/syslinux.cfg 		/boot/EFI/BOOT/syslinux.cfg.bak
cp /boot/boot/syslinux.cfg 		/boot/boot/syslinux.cfg.bak
cp /boot/boot/syslinux/syslinux.cfg 	/boot/boot/syslinux/syslinux.cfg.bak
cp /boot/EFI/batocera/syslinux.cfg 	/boot/EFI/batocera/syslinux.cfg.bak

#######################################################################################

#if [[ "$video_output" == *"DP"* ]]; then
#	cp /userdata/system/Batocera-CRT-Script/etc_configs/Monitors_config/10-monitor.conf-DP /etc/X11/xorg.conf.d/10-monitor.conf
#	chmod 644 /etc/X11/xorg.conf.d/10-monitor.conf
#elif [[ "$video_output" == *"DVI"* ]]||[[ "$video_output" == *"VGA"* ]]||[[ "$video_output" == *"HDMI"* ]]; then
#	cp /userdata/system/Batocera-CRT-Script/etc_configs/Monitors_config/10-monitor.conf-DVI /etc/X11/xorg.conf.d/10-monitor.conf
#	chmod 644 /etc/X11/xorg.conf.d/10-monitor.conf
#else
#	echo "####################################################"
#	echo "###   UNDER CONSTRUCTION                         ###"
#	echo "####################################################"
#	exit 1
#fi

# first time using the script save the 20-amdgpu.conf  in 20-amdgpu.conf.bak
if [ ! -f "/etc/X11/xorg.conf.d/20-amdgpu.conf.bak" ];then
	cp /etc/X11/xorg.conf.d/20-amdgpu.conf /etc/X11/xorg.conf.d/20-amdgpu.conf.bak
## ZFEbHVUE utilities
fi

cp /userdata/system/Batocera-CRT-Script//etc_configs/Monitors_config/20-amdgpu.conf /etc/X11/xorg.conf.d/20-amdgpu.conf
chmod 644 /etc/X11/xorg.conf.d/20-amdgpu.conf  

# first time using the script save the 20-radeon.conf  in 20-radeon.conf.bak
if [ ! -f "/etc/X11/xorg.conf.d/20-radeon.conf.bak" ];then
	cp /etc/X11/xorg.conf.d/20-radeon.conf /etc/X11/xorg.conf.d/20-radeon.conf.bak
fi 

cp /userdata/system/Batocera-CRT-Script/etc_configs/Monitors_config/20-radeon.conf /etc/X11/xorg.conf.d/20-radeon.conf
chmod 644 /etc/X11/xorg.conf.d/20-radeon.conf

##################################################################################################
python_directory=$(find /usr/lib/ -maxdepth 1 -type d -name "python*" -exec basename {} \; -quit)
new_path1="/usr/lib/${python_directory}/site-packages/configgen/"
# Check if the file exists and make a backup
if [ ! -f "${new_path1}emulatorlauncher.py.bak" ]; then
    echo "Backing up emulatorlauncher.py"
    cp "${new_path1}emulatorlauncher.py" 	"${new_path1}emulatorlauncher.py.bak"
fi
new_path2="/usr/lib/${python_directory}/site-packages/configgen/utils/"
if [ ! -f "/${new_path2}videoMode.py.bak" ];then
	cp "${new_path2}videoMode.py" 		"${new_path2}videoMode.py.bak"
fi
##################################################################################################



## Only for Batocera >= V32
case $Version_of_batocera in
 	v39)
		if [ "$ZFEbHVUE" == "1" ]; then

			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/Configgen/emulatorlauncher.py_ZFEbHVUE	"${new_path1}emulatorlauncher.py"
			chmod 755  "${new_path1}emulatorlauncher.py"
			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/Configgen/VideoMode.py_ZFEbHVUE 		"${new_path2}videoMode.py"
			chmod 755 "${new_path2}videoMode.py"

			if [ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]; then
			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/batocera-resolution-v38_Nvidia_driver_MYZAR_ZFEbHVUE 	/usr/bin/batocera-resolution
			else
			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/batocera-resolution-v38_MYZAR_ZFEbHVUE 			/usr/bin/batocera-resolution
			fi
			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/emulationstation-standalone-v38_ZFEbHVUE 		/usr/bin/emulationstation-standalone

		else
			cp "${new_path1}emulatorlauncher.py.bak" 	"${new_path1}emulatorlauncher.py"
			cp "${new_path2}videoMode.py.bak" 		"${new_path2}videoMode.py"

			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/batocera-resolution-v38_Myzar	 	/usr/bin/batocera-resolution
			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/emulationstation-standalone-v38		/usr/bin/emulationstation-standalone
			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/batocera-checkmode_Myzar			/usr/bin/batocera-checkmode
			chmod 755 /usr/bin/batocera-checkmode


		fi

		chmod 755 /usr/bin/batocera-resolution 
		chmod 755 /usr/bin/emulationstation-standalone
		sed -e "s/\[monitor-name\]/$monitor_name_MAME/g" -e "s/\[super_width\]/$super_width/g" -e "s/\[dotclock_min_value\]/$dotclock_min/g"  /userdata/system/Batocera-CRT-Script/etc_configs/switchres.ini-generic-v36 > /etc/switchres.ini
		sed -i "s/.*interlace_force_even   .*/        interlace_force_even      $IFE/" /etc/switchres.ini
  		chmod 755 /etc/switchres.ini

		cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/get_monitorRange  /usr/bin/get_monitorRange
		chmod 755 /usr/bin/get_monitorRange

	;;
	v40)
		if [ "$ZFEbHVUE" == "1" ]; then

			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/Configgen/emulatorlauncher.py_ZFEbHVUE	"${new_path1}emulatorlauncher.py"
			chmod 755  "${new_path1}emulatorlauncher.py"
			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/Configgen/VideoMode.py-v40_ZFEbHVUE	"${new_path2}videoMode.py"
			chmod 755 "${new_path2}videoMode.py"

			if [ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]; then
			#cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/batocera-resolution-v40_Nvidia_driver_MYZAR_ZFEbHVUE 			/usr/bin/batocera-resolution
			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/batocera-resolution-v40_Nvidia_driver_MYZAR_ZFEbHVUE-MultiScreen 	/usr/bin/batocera-resolution
			else
			#cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/batocera-resolution-v40_MYZAR_ZFEbHVUE 			/usr/bin/batocera-resolution
			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/batocera-resolution-v40_MYZAR_ZFEbHVUE-MultiScreen	/usr/bin/batocera-resolution

			fi
			#cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/emulationstation-standalone-v40_ZFEbHVUE 		/usr/bin/emulationstation-standalone
			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/emulationstation-standalone-v40_ZFEbHVUE-MultiScreen	/usr/bin/emulationstation-standalone

		else
			cp "${new_path1}emulatorlauncher.py.bak" 	"${new_path1}emulatorlauncher.py"
			cp "${new_path2}videoMode.py.bak" 		"${new_path2}videoMode.py"

			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/batocera-resolution-v40_Myzar	 	/usr/bin/batocera-resolution
			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/emulationstation-standalone-v40		/usr/bin/emulationstation-standalone
			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/batocera-checkmode_Myzar			/usr/bin/batocera-checkmode
			chmod 755 /usr/bin/batocera-checkmode


		fi

		chmod 755 /usr/bin/batocera-resolution 
		chmod 755 /usr/bin/emulationstation-standalone
		sed -e "s/\[monitor-name\]/$monitor_name_MAME/g" -e "s/\[super_width\]/$super_width/g" -e "s/\[dotclock_min_value\]/$dotclock_min/g"  /userdata/system/Batocera-CRT-Script/etc_configs/switchres.ini-generic-v36 > /etc/switchres.ini
		sed -i "s/.*interlace_force_even   .*/        interlace_force_even      $IFE/" /etc/switchres.ini
  		chmod 755 /etc/switchres.ini

		cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/get_monitorRange  /usr/bin/get_monitorRange
		chmod 755 /usr/bin/get_monitorRange

	;;

	v41)
		if [ "$ZFEbHVUE" == "1" ]; then

			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/Configgen/emulatorlauncher.py_v41_ZFEbHVUE	"${new_path1}emulatorlauncher.py"
			chmod 755  "${new_path1}emulatorlauncher.py"
			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/Configgen/VideoMode.py-v41_ZFEbHVUE		"${new_path2}videoMode.py"
			chmod 755 "${new_path2}videoMode.py"

			if [ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]; then
			#cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/batocera-resolution-v40_Nvidia_driver_MYZAR_ZFEbHVUE 			/usr/bin/batocera-resolution
			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/batocera-resolution-v41_Nvidia_driver_MYZAR_ZFEbHVUE-MultiScreen 	/usr/bin/batocera-resolution
			else
			#cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/batocera-resolution-v40_MYZAR_ZFEbHVUE 			/usr/bin/batocera-resolution
			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/batocera-resolution-v41_MYZAR_ZFEbHVUE-MultiScreen	/usr/bin/batocera-resolution

			fi
			#cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/emulationstation-standalone-v40_ZFEbHVUE 		/usr/bin/emulationstation-standalone
			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/emulationstation-standalone-v41_ZFEbHVUE-MultiScreen	/usr/bin/emulationstation-standalone

		else
			cp "${new_path1}emulatorlauncher.py.bak" 	"${new_path1}emulatorlauncher.py"
			cp "${new_path2}videoMode.py.bak" 		"${new_path2}videoMode.py"

			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/batocera-resolution-v40_Myzar	 	/usr/bin/batocera-resolution
			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/emulationstation-standalone-v40		/usr/bin/emulationstation-standalone
			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/batocera-checkmode_Myzar			/usr/bin/batocera-checkmode
			chmod 755 /usr/bin/batocera-checkmode


		fi

		chmod 755 /usr/bin/batocera-resolution 
		chmod 755 /usr/bin/emulationstation-standalone
		sed -e "s/\[monitor-name\]/$monitor_name_MAME/g" -e "s/\[super_width\]/$super_width/g" -e "s/\[dotclock_min_value\]/$dotclock_min/g"  /userdata/system/Batocera-CRT-Script/etc_configs/switchres.ini-generic-v36 > /etc/switchres.ini
		sed -i "s/.*interlace_force_even   .*/        interlace_force_even      $IFE/" /etc/switchres.ini
  		chmod 755 /etc/switchres.ini

		cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/get_monitorRange  /usr/bin/get_monitorRange
		chmod 755 /usr/bin/get_monitorRange

                #only for V41. Xemu from V42 to fixe a Mesa isse with AAMD
                cp -r /userdata/system/Batocera-CRT-Script/UsrBin_configs/xemu_v41/usr /	
		chmod 755 /usr/bin/xemu

	;;



	*)
		echo "PROBLEM OF VERSION"
		exit 1;
	;;
esac

cp /etc/switchres.ini /etc/switchres.ini.bak

#stop ES
if [ ! -f "/usr/bin/stop" ];then
	touch /usr/bin/stop
	echo "#!/bin/bash" 				>> /usr/bin/stop
	echo  "/etc/init.d/S31emulationstation stop" 	>> /usr/bin/stop
	chmod 755 /usr/bin/stop
fi
#start ES
if [ ! -f "/usr/bin/start" ];then
	touch /usr/bin/start
	echo "#!/bin/bash" 				>> /usr/bin/start
	echo  "/etc/init.d/S31emulationstation start" 	>> /usr/bin/start
	chmod 755 /usr/bin/start
fi


#######################################################################################
## Remove Beta name from splash screen if using a beta.
#######################################################################################
if [ -f "/usr/share/batocera/splash/splash.srt" ];then
	mv /usr/share/batocera/splash/splash.srt /usr/share/batocera/splash/splash.srt.bak
fi
#######################################################################################
## make splash screen rotation if using tate mode (right or left).
#######################################################################################
if [ ! -f "/usr/share/batocera/splash/boot-logo.png.bak" ]; then
	cp /usr/share/batocera/splash/boot-logo.png /usr/share/batocera/splash/boot-logo.png.bak
fi
cp /userdata/system/Batocera-CRT-Script/Boot_logos/boot-logo.png /usr/share/batocera/splash/boot-logo.png 
if [ "$display_rotate" == "right" ];then

	cp /userdata/system/Batocera-CRT-Script/Boot_logos/boot-logo_90.png /usr/share/batocera/splash/boot-logo.png 
fi
if [ "$display_rotate" == "inverted" ];then

	cp /userdata/system/Batocera-CRT-Script/Boot_logos/boot-logo_180.png /usr/share/batocera/splash/boot-logo.png 
fi
if  [ "$display_rotate" == "left" ]; then
	cp /userdata/system/Batocera-CRT-Script/Boot_logos/boot-logo_270.png /usr/share/batocera/splash/boot-logo.png  
fi
#######################################################################################
#######################################################################################
##         USB Arcade Encoders (multiple choices) for Arcade cabinet 
#######################################################################################
#######################################################################################

echo ""
echo "#######################################################################"
echo "##     USB Arcade Encoder(s) :  Multiple choices are possible        ##"
echo "#######################################################################"
declare -a Encoder_inputs=\($(ls -1 /dev/input/by-id/| tr "\012" " "| sed -e's, ," ",g' -e 's,^,",' -e 's," "$,",')\)
for var in "${!Encoder_inputs[@]}" ; do echo "			$((var+1)) : ${Encoder_inputs[$var]}"; done
echo "                        0 : Exit for USB Arcade Encoder(s)                   "
echo "#######################################################################"  
echo "##                                                                   ##"
echo "##            Make your choice(s) for one two or more                ##"
echo "##  for several encoders put virgule or space between your choices   ##"
echo "##                                                                   ##"
echo "##  If you don't have an Arcade Encoder(s) or if you want to let     ##"
echo "##       batocera configure automatically your Arcade Encoder(s)     ##"
echo "##                                                                   ##"	
echo "##               IT IS RECOMMANDED TO PRESS 0 OR ENTER               ##"
echo "##                                                                   ##"
echo "#######################################################################"
echo -n "                                  "
read Encoder_choice

if [ "x$Encoder_choice" != "x0" ] ; then
var_choix="`echo $Encoder_choice | sed -e 's/,/ /g'`"
for i in $var_choix; do echo -e "                    your choice is : ${Encoder_inputs[$i-1]}" ; touch /usr/share/batocera/datainit/system/configs/xarcade2jstick/${Encoder_inputs[$((i-1))]};done
else 
	echo "No USB Arcade encoder(s) has been choosen"
fi



#######################################################################################
# Select the calibration resolution for your GunCon II
#######################################################################################

echo "####################################################################################"
echo "##         Configure a specific resolution the calibration of your GunCon2        ##"  | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
echo "##                                                                                ##"
echo "##      (DEFAULT) NO  for AMD/ATI or Nvidia(Maxwell) Default is (320x240@60Hz)    ##"
echo "##                YES for Nvidia with Dotclok_min=25.0 (try 640x480@60Hz)         ##"
echo "##                                                                                ##"
echo "##  EXPERIMENTAL : FOR AMD/ATI/NVIDIA YOU CAN USE OWN RESOLUTION AND SEE WHAT     ##"
echo "##  IS BETTER AND REPORT US YOUR EXPERIENCE IN GAMES. YOU CAN TRY 640x480@60Hz    ##"
echo "##  OR WHAT YOU WANT LIKE 769x576@50Hz. FOR THAT TYPE YES                         ##"
echo "##                                                                                ##"
echo "##                 Press Enter To Select DEFAULT Value 320x240                    ##"
echo "####################################################################################"
echo ""
declare -a Calibration_Guncon2_choice=( "NO" "YES" )
for var in "${!Calibration_Guncon2_choice[@]}" ; do echo "			$((var+1)) : ${Calibration_Guncon2_choice[$var]}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log; done
echo ""
echo "#######################################################################"
echo "##                         Make your choice                          ##"
echo "#######################################################################"
echo -n "                                  "
read choice_Calibration_Guncon2

# Handle invalid input or default value (ENTER)
while [[ ! ${choice_Calibration_Guncon2} =~ ^[1-$((var+1))]$ ]] && [[ -n ${choice_Calibration_Guncon2} ]]; do
	echo -n "Select option 1 to $((var+1)) or press ENTER for default: "
	read choice_Calibration_Guncon2
done

if [ -z "$choice_Calibration_Guncon2" ] || [ "$choice_Calibration_Guncon2" == "1" ]; then
	echo -e "                    Your choice is: ${GREEN}Bypass with default resolution (320x240@60Hz)${NOCOLOR}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
	# Set default resolution variables
	Guncon2_x=320
	Guncon2_y=240
	Guncon2_freq=60
	Guncon2_res=($Guncon2_x"x"$Guncon2_y)
else
	echo -e "                    Your choice is: ${GREEN}Custom resolution setup${NOCOLOR}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log

	# Custom horizontal resolution
	echo "###############################################################################"
	echo "##      Select your custom horizontal resolution for Guncon2 calibration     ##"
	echo "###############################################################################"
	echo -n "                                  "
	read Guncon2_x
	while [[ ! $Guncon2_x =~ ^[0-9]+$ || "$Guncon2_x" -lt 0 ]]; do
		echo -n "Enter a valid number greater than 0 for Guncon2_x: "
		read Guncon2_x
	done
	echo -e "                    CUSTOM Guncon2_x Horizontal resolution  = ${GREEN}${Guncon2_x}${NOCOLOR}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log

	# Custom vertical resolution
	echo "###############################################################################"
	echo "##      Select your custom vertical resolution for Guncon2 calibration       ##"
	echo "###############################################################################"
	echo -n "                                  "
	read Guncon2_y
	while [[ ! $Guncon2_y =~ ^[0-9]+$ || "$Guncon2_y" -lt 0 ]]; do
		echo -n "Enter a valid number greater than 0 for Guncon2_y: "
		read Guncon2_y
	done
	echo -e "                    CUSTOM Guncon2_y Vertical resolution  = ${GREEN}${Guncon2_y}${NOCOLOR}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log

	# Custom frequency
	echo "###############################################################################"
	echo "##      Select your custom frequency resolution for Guncon2 calibration      ##"
	echo "###############################################################################"
	echo -n "                                  "
	read Guncon2_freq
	while [[ ! $Guncon2_freq =~ ^[0-9]+$ || "$Guncon2_freq" -lt 0 ]]; do
		echo -n "Enter a valid number greater than 0 for Guncon2_freq: "
		read Guncon2_freq
	done
	echo -e "                    CUSTOM frequency resolution  = ${GREEN}${Guncon2_freq}${NOCOLOR}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log

	# Set custom resolution
	Guncon2_res=($Guncon2_x"x"$Guncon2_y)
fi



echo ""
echo "#######################################################################"
echo "##                                                                   ##"
echo "##             BEFORE YOU PRESS ENTER READ THE FOLLOWING TEXT        ##"   
echo "##                                                                   ##"
echo "##      REMEMBER AUTHORS OF THIS SCRIPT WILL BE NOT RESPONSIBLE      ##"
echo "##                      FOR ANY DAMAGES TO YOUR CRT                  ##"
echo "##                                                                   ##"
echo "##                     DO A SHUTDOWN OF YOUR SYSTEM                  ##"
echo "##         BE SURE YOU PUT THE RIGHT CABLE AND CONNECTION FOR 15KHz  ##"
echo "##       BE SURE YOU HAVE SOME PROTECTIONS FOR YOUR MONITOR          ##"
echo "##                                                                   ##"
echo "##    RESTART YOUR BATOCERA SYSTEM AND HAVE FUN IN 15KHz EXPERIENCE  ##"
echo "##                                                                   ##"
echo "#######################################################################"
echo ""
echo -n -e "                       PRESS ${BLUE}ENTER${NOCOLOR} TO FINISH "
read 

#######################################################################################
# Create files for adjusting your CRT
#######################################################################################
cp -a /userdata/system/Batocera-CRT-Script/Geometry_modeline/crt/ /userdata/roms/
cp /userdata/system/Batocera-CRT-Script/Geometry_modeline/es_systems_crt.cfg /userdata/system/configs/emulationstation/es_systems_crt.cfg
cp /userdata/system/Batocera-CRT-Script/Geometry_modeline/CRT.png /usr/share/emulationstation/themes/es-theme-carbon/art/consoles/CRT.png
cp /userdata/system/Batocera-CRT-Script/Geometry_modeline/CRT.svg /usr/share/emulationstation/themes/es-theme-carbon/art/logos/CRT.svg
chmod 755 /userdata/roms/crt/es_adjust_tool.sh
chmod 755 /userdata/roms/crt/geometry.sh
chmod 755 /userdata/system/Batocera-CRT-Script/Geometry_modeline/es_tool.sh
chmod 755 /userdata/system/Batocera-CRT-Script/Geometry_modeline/geometry.sh
chmod 0644 /userdata/roms/crt/es_adjust_tool.sh.keys
chmod 0644 /userdata/roms/crt/geometry.sh.keys
chmod 755 /userdata/roms/crt/grid_tool.sh
chmod 755 /userdata/system/Batocera-CRT-Script/Geometry_modeline/grid_tool.sh
chmod 0644 /userdata/roms/crt/grid_tool.sh.keys

#######################################################################################
# Create geometryForVideomodes.sh  for adjusting resoltuion in videomodes.conf for your CRT
#######################################################################################

#cp Batocera-CRT-Script/Geometry_modeline/crt/geometryForVideomodes.sh /userdata/roms/crt/geometryForVideomodes.sh
#chmod 755 /userdata/roms/crt/geometryForVideomodes.sh

#######################################################################################
# Create GunCon2 LUA plugin for GroovyMame for V39, V40 and V41
#######################################################################################
## if the folder doesn't exist, it will be created now
if [ ! -d "/usr/bin/mame/plugins/gunlight" ];then
	mkdir /usr/bin/mame/plugins/gunlight
fi
if ([ "$Version_of_batocera" == "v39" ]||[ "$Version_of_batocera" == "v40" ]||[ "$Version_of_batocera" == "v41" ]); then
	cp /userdata/system/Batocera-CRT-Script/GunCon2/gunlight/gunlight_menu.lua /usr/bin/mame/plugins/gunlight/gunlight_menu.lua
	cp /userdata/system/Batocera-CRT-Script/GunCon2/gunlight/gunlight_save.lua /usr/bin/mame/plugins/gunlight/gunlight_save.lua
	cp /userdata/system/Batocera-CRT-Script/GunCon2/gunlight/init.lua /usr/bin/mame/plugins/gunlight/init.lua
	cp /userdata/system/Batocera-CRT-Script/GunCon2/gunlight/plugin.json /usr/bin/mame/plugins/gunlight/plugin.json
	chmod 644 /usr/bin/mame/plugins/gunlight/gunlight_menu.lua
	chmod 644 /usr/bin/mame/plugins/gunlight/gunlight_save.lua
	chmod 644 /usr/bin/mame/plugins/gunlight/init.lua
	chmod 644 /usr/bin/mame/plugins/gunlight/plugin.json
fi

#######################################################################################
# Create GunCon2 shader for V36, V37 and v38
#######################################################################################
## if the folder doesn't exist, it will be created now
if [ ! -d "/usr/share/batocera/shaders/configs/lightgun-shader" ];then
	mkdir /usr/share/batocera/shaders/configs/lightgun-shader
fi
	cp /userdata/system/Batocera-CRT-Script/GunCon2/shader/lightgun-shader/rendering-defaults.yml /usr/share/batocera/shaders/configs/lightgun-shader/rendering-defaults.yml
	chmod 644 /usr/share/batocera/shaders/configs/lightgun-shader/rendering-defaults.yml
	cp /userdata/system/Batocera-CRT-Script/GunCon2/shader/misc/image-adjustment_lgun.slangp /usr/share/batocera/shaders/misc/image-adjustment_lgun.slangp
	cp /userdata/system/Batocera-CRT-Script/GunCon2/shader/misc/shaders/image-adjustment_lgun.slang /usr/share/batocera/shaders/misc/shaders/image-adjustment_lgun.slang
	chmod 644 /usr/share/batocera/shaders/misc/image-adjustment_lgun.slangp
	chmod 644 /usr/share/batocera/shaders/misc/shaders/image-adjustment_lgun.slang

	if [ ! -f "/etc/udev/rules.d/99-guncon.rules.bak" ];then                                                           
		cp /etc/udev/rules.d/99-guncon.rules /etc/udev/rules.d/99-guncon.rules.bak                       
	fi
 
	cp /userdata/system/Batocera-CRT-Script/GunCon2/99-guncon.rules-generic /etc/udev/rules.d/99-guncon.rules

        if [ ! -f "/usr/bin/guncon2_calibrate.sh.bak" ];then                                                           
		cp /usr/bin/guncon2_calibrate.sh /usr/bin/guncon2_calibrate.sh.bak                      
	fi

	sed -e "s/\[guncon2_x\]/$Guncon2_x/g" -e "s/\[guncon2_y\]/$Guncon2_y/g" -e "s/\[guncon2_f\]/$Guncon2_freq/g" -e "s/\[guncon2_res\]/$Guncon2_res/g" \
		/userdata/system/Batocera-CRT-Script/GunCon2/guncon2_calibrate.sh-generic  > /usr/bin/guncon2_calibrate.sh
        chmod 755 /usr/bin/guncon2_calibrate.sh


	if [ ! -f "/usr/bin/calibrate.py.bak" ];then                                                           
		cp /usr/bin/calibrate.py /usr/bin/calibrate.py.bak                      
	fi
	if [ "$ES_rotation" == "NORMAL" ] || [ "$ES_rotation" == "INVERTED" ]; then	
		sed -e "s/\[guncon2_x\]/$Guncon2_x/g" -e "s/\[guncon2_y\]/$Guncon2_y/g"  -e "s/\[guncon2_res\]/$Guncon2_res/g" \
		       	/userdata/system/Batocera-CRT-Script/GunCon2/calibrate.py-generic   > /usr/bin/calibrate.py
	else
		sed -e "s/\[guncon2_y\]/$Guncon2_x/g" -e "s/\[guncon2_x\]/$Guncon2_y/g"  -e "s/\[guncon2_res\]/$Guncon2_res/g" \
		       	/userdata/system/Batocera-CRT-Script/GunCon2/calibrate.py-generic   > /usr/bin/calibrate.py
	fi
	chmod 755 /usr/bin/calibrate.py

#######################################################################################
# Add VNC server files to /lib & /usr/lib for v41
#######################################################################################
#mv /lib/libcrypt.so.1 /lib/libcrypt.so.1.bak
cp /userdata/system/Batocera-CRT-Script/install-vnc_server_batocera/libcrypt.so.1 /lib/libcrypt.so.1 
cp /userdata/system/Batocera-CRT-Script/install-vnc_server_batocera/libcrypt.so.1 /usr/lib/libcrypt.so.1
cp /userdata/system/Batocera-CRT-Script/install-vnc_server_batocera/libvncclient.so.1 /usr/lib/libvncclient.so.1
cp /userdata/system/Batocera-CRT-Script/install-vnc_server_batocera/libvncserver.so.1 /usr/lib/libvncserver.so.1
cp /userdata/system/Batocera-CRT-Script/install-vnc_server_batocera/libsasl2.so.2 /usr/lib/libsasl2.so.2
cp /userdata/system/Batocera-CRT-Script/install-vnc_server_batocera/vnc /usr/bin/vnc
cp /userdata/system/Batocera-CRT-Script/install-vnc_server_batocera/x11vnc /usr/bin/x11vnc
cp /userdata/system/Batocera-CRT-Script/install-vnc_server_batocera/vnc-scaled /usr/bin/vnc-scaled

chmod 0755 /lib/libcrypt.so.1
chmod 0644 /usr/lib/libcrypt.so.1
chmod 0644 /usr/lib/libvncclient.so.1
chmod 0644 /usr/lib/libvncserver.so.1
chmod 0644 /usr/lib/libsasl2.so.2
chmod +x /usr/bin/vnc
chmod +x /usr/bin/x11vnc
chmod +x /usr/bin/vnc-scaled

#######################################################################################
# Add Overlays and Overrides for handheld system Tool
#######################################################################################
cp /userdata/system/Batocera-CRT-Script/extra/overlays_overrides.sh /userdata/roms/crt
cp /userdata/system/Batocera-CRT-Script/extra/overlays_overrides.sh.keys /userdata/roms/crt
chmod 755 /userdata/roms/crt/overlays_overrides.sh
chmod 644 /userdata/roms/crt/overlays_overrides.sh.keys
chmod 755 /userdata/system/Batocera-CRT-Script/extra/overlays_overrides_script.sh

#######################################################################################
# Add Media Keys with restart for Xorg and restart Emulation Station
#######################################################################################
cp /userdata/system/Batocera-CRT-Script/extra/media_keys/multimedia_keys.conf /userdata/system/configs/
cp /userdata/system/Batocera-CRT-Script/extra/media_keys/esrestart /usr/bin
cp /userdata/system/Batocera-CRT-Script/extra/media_keys/xrestart /usr/bin
cp /userdata/system/Batocera-CRT-Script/extra/media_keys/emukill /usr/bin
chmod 644 /userdata/system/configs/multimedia_keys.conf
chmod 755 /usr/bin/esrestart
chmod 755 /usr/bin/xrestart
chmod 755 /usr/bin/emukill

#######################################################################################
# Add Kodi to ports folder
#######################################################################################
cp /userdata/system/Batocera-CRT-Script/extra/Kodi/Kodi.sh /userdata/roms/ports
chmod 755 /userdata/roms/ports/Kodi.sh

#######################################################################################
## Save in compilation in batocera image
#######################################################################################
batocera-save-overlay
#######################################################################################
## Put the custom file for the 15KHz modelines for ES and Games 
#######################################################################################

if [ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]; then

	if [  -f "/userdata/system/99-nvidia.conf" ]; then
		cp /userdata/system/99-nvidia.conf /userdata/system/99-nvidia.conf.bak
        fi 

	# MYZAR's WORK and TESTS : THX DUDE !!
	if [ "$CRT_Freq" == "15KHz" ]; then
		sed -e  "s/.*Modeline.*/    Modeline            $MODELINE_CUSTOM/" -e "s/\[card_display\]/$video_modeline/g" /userdata/system/Batocera-CRT-Script/System_configs/Nvidia/99-nvidia.conf-generic_15 > /userdata/system/99-nvidia.conf
	elif [ "$CRT_Freq" == "25KHz" ]; then
		sed -e  "s/.*Modeline.*/    Modeline            $MODELINE_CUSTOM/" -e "s/\[card_display\]/$video_modeline/g" /userdata/system/Batocera-CRT-Script/System_configs/Nvidia/99-nvidia.conf-generic_25 > /userdata/system/99-nvidia.conf
	else
		sed -e "s/\[card_display\]/$video_modeline/g"  /userdata/system/Batocera-CRT-Script/System_configs/Nvidia/99-nvidia.conf-generic_31 > /userdata/system/99-nvidia.conf
	fi

	chmod 644 /userdata/system/99-nvidia.conf

	cp /userdata/system/99-nvidia.conf /userdata/system/99-nvidia.conf.bak
else

	if [ -f "/userdata/system/99-nvidia.conf" ]; then
		cp /userdata/system/99-nvidia.conf /userdata/system/99-nvidia.conf.bak
		rm /userdata/system/99-nvidia.conf
	fi

fi



######################################################################################
# Create a first_script.sh for exiting of Emulationstation
#######################################################################################
##if the folder doesn't exist, it will be create now
if [ ! -d "/userdata/system/scripts" ];then
    mkdir    /userdata/system/scripts
fi 
if [ "$BOOT_RESOLUTION" == "1" ]; then

	sed 	-e "s/\[display_mame_rotation\]/$display_mame_rotate/g" -e "s/\[display_fbneo_rotation\]/$display_fbneo_rotate/g" -e "s/\[display_libretro_rotation\]/$display_libretro_rotate/g" \
		-e "s/\[display_standalone_rotation\]/$display_standalone_rotate/g" -e "s/\[display_ES_rotation\]/$display_rotate/g" \
		-e "s/\[card_display\]/$video_modeline/g" -e "s/\[es_resolution\]/$RES_EDID/g" /userdata/system/Batocera-CRT-Script/System_configs/First_script/first_script.sh-generic-v33 > /userdata/system/scripts/first_script.sh
else
	sed 	-e "s/\[display_mame_rotation\]/$display_mame_rotate/g" -e "s/\[display_fbneo_rotation\]/$display_fbneo_rotate/g" -e "s/\[display_libretro_rotation\]/$display_libretro_rotate/g" \
		-e "s/\[display_standalone_rotation\]/$display_standalone_rotate/g" -e "s/\[display_ES_rotation\]/$display_rotate/g" \
		-e "s/\[card_display\]/$video_modeline/g" -e "s/\[es_resolution\]/$RES_EDID_SCANNING/g" /userdata/system/Batocera-CRT-Script/System_configs/First_script/first_script.sh-generic-v33 > /userdata/system/scripts/first_script.sh
fi
chmod 755 /userdata/system/scripts/first_script.sh
######################################################################################
# Create 1_GunCon2.sh and GunCon2_Calibration.sh
######################################################################################
sed -e "s/\[card_display\]/$video_modeline/g" /userdata/system/Batocera-CRT-Script/System_configs/First_script/1_GunCon2.sh-generic > /userdata/system/scripts/1_GunCon2.sh
chmod 755 /userdata/system/scripts/1_GunCon2.sh
sed -e "s/\[card_display\]/$video_modeline/g" /userdata/system/Batocera-CRT-Script/GunCon2/GunCon2_Calibration.sh-generic > /userdata/roms/crt/GunCon2_Calibration.sh
chmod 755 /userdata/roms/crt/GunCon2_Calibration.sh


#######################################################################################
## Copy of batocera.conf for Libretro cores for use with Switchres
#######################################################################################
# first time using the script save the batocera.conf in batocera.conf.bak
if [ ! -f "/userdata/system/batocera.conf.bak" ];then
	cp /userdata/system/batocera.conf /userdata/system/batocera.conf.bak
fi


# avoid append on each script launch
LINE_NO=$(sed -n '/## ES Settings, See wiki page on how to center EmulationStation/{=;q;}' /userdata/system/batocera.conf.bak)

if [ -z "$LINE_NO" ]; then 
	cp /userdata/system/batocera.conf.bak /userdata/system/batocera.conf 
else 
	truncate -s 0 batocera.conf
	sed -n "1,$(( LINE_NO - 1 )) p; $LINE_NO q" /userdata/system/batocera.conf.bak > /userdata/system/batocera.conf
fi

#######################################################################################
## how create a file /userdatat/system/es.arg.override
#######################################################################################
file="/userdata/system/es.arg.override"

#screensize_x_new=$H_RES_EDID
#screensize_y_new=$V_RES_EDID
screensizeoffset_x_new=00
screensizeoffset_y_new=00
screenoffset_x_new=00
screenoffset_y_new=00

if [ -f "$file" ]; then
	rm $file
fi
touch $file
#echo "screensize_x $screensize_x_new" > "$file"
#echo "screensize_y $screensize_y_new" >> "$file"
echo "screensizeoffset_x $screensizeoffset_x_new" > "$file"
echo "screensizeoffset_y $screensizeoffset_y_new" >> "$file"
echo "screenoffset_x $screenoffset_x_new" >> "$file"
echo "screenoffset_y $screenoffset_y_new" >> "$file"
chmod 644 $file

#######################################################################################
## how to center EmulationStation
#######################################################################################
file_BatoceraConf="/userdata/system/batocera.conf"

if [ "$BOOT_RESOLUTION_ES" == "1" ]; then
	echo $Resolution_es 								>> "$file_BatoceraConf"
fi
echo "## ES Settings, See wiki page on how to center EmulationStation" 			>> "$file_BatoceraConf"

if [ "$ES_rotation" == "NORMAL" ] || [ "$ES_rotation" == "INVERTED" ]; then
	es_customsargs="es.customsargs=--screensize "$H_RES_EDID" "$V_RES_EDID" --screenoffset 00 00"
	es_arg="--screensize "$H_RES_EDID" "$V_RES_EDID" --screenoffset 00 00"
else
	es_customsargs="es.customsargs=--screensize "$V_RES_EDID" "$H_RES_EDID" --screenoffset 00 00"
	es_arg="--screensize "$V_RES_EDID" "$H_RES_EDID" --screenoffset 00 00"
fi
echo $es_customsargs 									>> "$file_BatoceraConf"

#######################################################################################"
## CRT GLOBAL CONFIG FOR RETROARCH
#######################################################################################"
echo "###################################################" 				>> "$file_BatoceraConf"
echo "#	CRT CONFIG RETROARCH" 								>> "$file_BatoceraConf"
echo "###################################################" 				>> "$file_BatoceraConf"
echo "global.retroarch.menu_driver=rgui" 						>> "$file_BatoceraConf"
echo "global.retroarch.menu_show_advanced_settings=true" 				>> "$file_BatoceraConf"
echo "global.retroarch.menu_enable_widgets=false" 					>> "$file_BatoceraConf"
echo "global.retroarch.crt_switch_resolution = \"4\"" 					>> "$file_BatoceraConf"
if [ "$dotclock_min" == "25.0" ]; then
	echo "global.retroarch.crt_switch_resolution_super = \"$super_width\"" 		>> "$file_BatoceraConf"
else
	echo "global.retroarch.crt_switch_resolution_super = \"0\"" 			>> "$file_BatoceraConf"
fi
echo "global.retroarch.crt_switch_hires_menu = \"true\""  				>> "$file_BatoceraConf"
echo "###################################################" 				>> "$file_BatoceraConf"
echo "#	DISABLE DEFAULT SHADER, BILINEAR FILTERING & VRR"  				>> "$file_BatoceraConf"
echo "###################################################" 				>> "$file_BatoceraConf"
echo "global.shaderset=none" 								>> "$file_BatoceraConf"
echo "global.smooth=0" 									>> "$file_BatoceraConf"
echo "global.retroarch.vrr_runloop_enable=0" 						>> "$file_BatoceraConf"
echo "###################################################" 				>> "$file_BatoceraConf"
echo "#	DISABLE GLOBAL NOTIFICATIONS IN RETROARCH" 					>> "$file_BatoceraConf"
echo "###################################################" 				>> "$file_BatoceraConf"
echo "##  Disable Retroarch Notifications for setting refresh rate" 			>> "$file_BatoceraConf"
echo "global.retroarch.notification_show_refresh_rate = \"false\"" 			>> "$file_BatoceraConf"
echo "## Change Notifications Size. Default is 32 (way to big) but 10 looks better on a CRT " >> "$file_BatoceraConf"
echo "global.retroarch.video_font_size = 10" 						>> "$file_BatoceraConf"
echo "### Disable Everything with notifications" 					>> "$file_BatoceraConf"
echo "global.retroarch.settings_show_onscreen_display = \"false\"" 			>> "$file_BatoceraConf"
#########################################################################################################
##  SOME GLOBAL RETROARCH NOTIFICATIONS CAN BE AVOID WITH REPLACING TRUE BY FALSE    
#########################################################################################################
echo "## global notifications can be avoid with replacing \"true\" by \"false\"" 	>> "$file_BatoceraConf"
echo "global.retroarch.notification_show_autoconfig = \"true\"" 			>> "$file_BatoceraConf"
echo "global.retroarch.notification_show_cheats_applied = \"true\"" 			>> "$file_BatoceraConf"
echo "global.retroarch.notification_show_config_override_load = \"true\"" 		>> "$file_BatoceraConf"
echo "global.retroarch.notification_show_fast_forward = \"true\"" 			>> "$file_BatoceraConf"
echo "global.retroarch.notification_show_netplay_extra = \"true\"" 			>> "$file_BatoceraConf"
echo "global.retroarch.notification_show_patch_applied = \"true\"" 			>> "$file_BatoceraConf"
echo "global.retroarch.notification_show_remap_load = \"true\"" 			>> "$file_BatoceraConf"
echo "global.retroarch.notification_show_screenshot = \"true\"" 			>> "$file_BatoceraConf"
echo "global.retroarch.notification_show_set_initial_disk = \"true\"" 			>> "$file_BatoceraConf"
echo "###################################################" 				>> "$file_BatoceraConf"
echo "##  GUNCON2 SHADER SAVE FIX" 							>> "$file_BatoceraConf"
echo "###################################################" 				>> "$file_BatoceraConf"
echo "global.retroarch.video_shader_preset_save_reference_enable = \"true\"" 		>> "$file_BatoceraConf"
echo "global.retroarch.video_shader_enable = \"true\"" 					>> "$file_BatoceraConf"
echo "###################################################" 				>> "$file_BatoceraConf"
echo "##  GLOBAL EMULATOR SETTINGS" 							>> "$file_BatoceraConf"
echo "###################################################" 				>> "$file_BatoceraConf"
echo "global.bezel=none" 								>> "$file_BatoceraConf"
echo "global.bezel.resize_tattoo=0" 							>> "$file_BatoceraConf"
echo "global.bezel.tattoo=0" 								>> "$file_BatoceraConf"
echo "global.bezel_stretch=0" 								>> "$file_BatoceraConf"
echo "global.hud=none" 									>> "$file_BatoceraConf"
#######################################################################################
##  Rotation of EmulationStation
#######################################################################################

term_rotation="display.rotate="
term_es_rotation=$term_rotation$((es_rotation_choice-1))
echo "# ES ROTATION  MODE" 								 >> "$file_BatoceraConf"

echo $term_es_rotation									 >> "$file_BatoceraConf"


#######################################################################################
## Mame initialisation Batocera not for RetroLX at this time
#######################################################################################

cd /usr/bin/mame
./mame -cc
case $Version_of_batocera in
 	v39)
		if [ ! -d "/userdata/system/configs/mame" ];then
			mkdir /userdata/system/configs/mame
			mkdir /userdata/system/configs/mame/ini
		elif [ ! -d "/userdata/system/configs/mame/ini" ];then
			mkdir /userdata/system/configs/mame/ini
		fi
		mv /usr/bin/mame/*.ini /userdata/system/configs/mame/
		sed -e "s/\[monitor-name\]/$monitor_name_MAME/g" -e "s/\[super_width_mame\]/$super_width_mame/g" -e "s/\[dotclock_min_mame\]/$dotclock_min_mame/g" \
			/userdata/system/Batocera-CRT-Script//Mame_configs/mame.ini-switchres-generic-v36 > /userdata/system/configs/mame/mame.ini
		chmod 644 /userdata/system/configs/mame/mame.ini
		cp /userdata/system/Batocera-CRT-Script/Mame_configs/ui.ini-switchres /userdata/system/configs/mame/ui.ini
		chmod 644 /userdata/system/configs/mame/ui.ini

 		cp /userdata/system/Batocera-CRT-Script/GunCon2/gunlight/plugin.ini /userdata/system/configs/mame/plugin.ini
		chmod 644 /userdata/system/configs/mame/plugin.ini
	;;
 	v40)
		if [ ! -d "/userdata/system/configs/mame" ];then
			mkdir /userdata/system/configs/mame
			mkdir /userdata/system/configs/mame/ini
		elif [ ! -d "/userdata/system/configs/mame/ini" ];then
			mkdir /userdata/system/configs/mame/ini
		fi
		mv /usr/bin/mame/*.ini /userdata/system/configs/mame/
		sed -e "s/\[monitor-name\]/$monitor_name_MAME/g" -e "s/\[super_width_mame\]/$super_width_mame/g" -e "s/\[dotclock_min_mame\]/$dotclock_min_mame/g" \
			/userdata/system/Batocera-CRT-Script//Mame_configs/mame.ini-switchres-generic-v36 > /userdata/system/configs/mame/mame.ini
		chmod 644 /userdata/system/configs/mame/mame.ini
		cp /userdata/system/Batocera-CRT-Script/Mame_configs/ui.ini-switchres /userdata/system/configs/mame/ui.ini
		chmod 644 /userdata/system/configs/mame/ui.ini

 		cp /userdata/system/Batocera-CRT-Script/GunCon2/gunlight/plugin.ini /userdata/system/configs/mame/plugin.ini
		chmod 644 /userdata/system/configs/mame/plugin.ini
	;;
	v41)
		if [ ! -d "/userdata/system/configs/mame" ];then
			mkdir /userdata/system/configs/mame
			mkdir /userdata/system/configs/mame/ini
		elif [ ! -d "/userdata/system/configs/mame/ini" ];then
			mkdir /userdata/system/configs/mame/ini
		fi
		mv /usr/bin/mame/*.ini /userdata/system/configs/mame/
		sed -e "s/\[monitor-name\]/$monitor_name_MAME/g" -e "s/\[super_width_mame\]/$super_width_mame/g" -e "s/\[dotclock_min_mame\]/$dotclock_min_mame/g" \
			/userdata/system/Batocera-CRT-Script//Mame_configs/mame.ini-switchres-generic-v36 > /userdata/system/configs/mame/mame.ini
		chmod 644 /userdata/system/configs/mame/mame.ini
		cp /userdata/system/Batocera-CRT-Script/Mame_configs/ui.ini-switchres /userdata/system/configs/mame/ui.ini
		chmod 644 /userdata/system/configs/mame/ui.ini

 		cp /userdata/system/Batocera-CRT-Script/GunCon2/gunlight/plugin.ini /userdata/system/configs/mame/plugin.ini
		chmod 644 /userdata/system/configs/mame/plugin.ini
	;;


	*)
		echo "Problem of version"
	;;
esac

cp /userdata/system/configs/mame/mame.ini       /userdata/system/configs/mame/mame.ini.bak 

#######################################################################################
## UPGRADE Mame  Batocera  create an folder for new binary of MAME (GroovyMame)
####################################################################################### 
if [ ! -d "/userdata/system//mame" ];then
	mkdir /userdata/system/mame
fi

####################################################################################### 
echo "###################################################"				>> "$file_BatoceraConf"
echo "##  CRT SYSTEM SETTINGS" 								>> "$file_BatoceraConf"
echo "###################################################" 				>> "$file_BatoceraConf"
echo "CRT.emulator=sh" 									>> "$file_BatoceraConf"
echo "CRT.core=sh" 									>> "$file_BatoceraConf"
echo "###################################################" 				>> "$file_BatoceraConf"
echo "##  GROOVYMAME EMULATOR SETTINGS" 						>> "$file_BatoceraConf"
echo "###################################################" 				>> "$file_BatoceraConf"
echo "mame.bezel=none" 									>> "$file_BatoceraConf"
echo "mame.bezel_stretch=0" 								>> "$file_BatoceraConf"
echo "mame.core=mame" 									>> "$file_BatoceraConf"
echo "mame.emulator=mame" 								>> "$file_BatoceraConf"
echo "mame.bezel.tattoo=0" 								>> "$file_BatoceraConf"
echo "mame.bgfxshaders=None" 								>> "$file_BatoceraConf"
echo "mame.hud=none" 									>> "$file_BatoceraConf"
echo "mame.switchres=1" 								>> "$file_BatoceraConf"
echo "###################################################" 				>> "$file_BatoceraConf"
echo "##  NEOGEO SYSTEM SETTINGS" 							>> "$file_BatoceraConf"
echo "###################################################" 				>> "$file_BatoceraConf"
echo "neogeo.bezel=none" 								>> "$file_BatoceraConf"
echo "neogeo.bezel_stretch=0" 								>> "$file_BatoceraConf"
echo "neogeo.core=mame" 								>> "$file_BatoceraConf"
echo "neogeo.emulator=mame" 							        >> "$file_BatoceraConf"
echo "neogeo.bezel.tattoo=0" 								>> "$file_BatoceraConf"
echo "neogeo.bgfxshaders=None" 								>> "$file_BatoceraConf"
echo "neogeo.hud=none"									>> "$file_BatoceraConf"
echo "neogeo.switchres=1" 								>> "$file_BatoceraConf"
echo "###################################################" 				>> "$file_BatoceraConf"
echo "##  MAME EMULATOR SETTINGS" 							>> "$file_BatoceraConf"
echo "##  APPLE2 / CAMPUTER LYNX / ACORN BBC/ELECTRON/ARCHIMEDE" 			>> "$file_BatoceraConf"
echo "###################################################" 				>> "$file_BatoceraConf"
echo "apple2.core=mame" 								>> "$file_BatoceraConf"
echo "apple2.emulator=mame" 								>> "$file_BatoceraConf"
echo "apple2.switchres=1" 								>> "$file_BatoceraConf"
echo "bbc.core=mame" 									>> "$file_BatoceraConf"
echo "bbc.emulator=mame" 								>> "$file_BatoceraConf"
echo "bbc.switchres=1" 									>> "$file_BatoceraConf"
echo "electron.core=mame" 								>> "$file_BatoceraConf"
echo "electron.emulator=mame" 								>> "$file_BatoceraConf"
echo "electron.switchres=1" 								>> "$file_BatoceraConf"
echo "archimedes.core=mame" 								>> "$file_BatoceraConf"
echo "archimedes.emulator=mame" 							>> "$file_BatoceraConf"
echo "archimedes.switchres=1" 								>> "$file_BatoceraConf"
echo "camplynx.core=mame"								>> "$file_BatoceraConf"
echo "camplynx.emulator=mame"								>> "$file_BatoceraConf"
echo "camplynx.switchres=1" 								>> "$file_BatoceraConf"
echo "###################################################" 				>> "$file_BatoceraConf"
echo "##  STANDALONE EMULATOR SETTINGS" 						>> "$file_BatoceraConf"
echo "###################################################" 				>> "$file_BatoceraConf"
echo "amiga500.core=A500" 								>> "$file_BatoceraConf"
echo "amiga500.cpu_compatibility=exact" 						>> "$file_BatoceraConf"
echo "amiga500.emulator=fsuae" 								>> "$file_BatoceraConf"
echo "amiga500.video_allow_rotate=true" 						>> "$file_BatoceraConf"
echo "amigacd32.core=CD32" 								>> "$file_BatoceraConf"
echo "amigacd32.emulator=fsuae" 							>> "$file_BatoceraConf"
echo "atarist.core=hatari" 								>> "$file_BatoceraConf"
echo "atarist.emulator=hatari" 								>> "$file_BatoceraConf"
echo "dos.core=dosbox" 									>> "$file_BatoceraConf"
echo "dos.emulator=dosbox" 								>> "$file_BatoceraConf"
echo "msx1.core=openmsx" 								>> "$file_BatoceraConf"
echo "msx1.emulator=openmsx" 								>> "$file_BatoceraConf"
echo "msx2.core=openmsx" 								>> "$file_BatoceraConf"
echo "msx2.emulator=openmsx"								>> "$file_BatoceraConf"
echo "msx2+.core=openmsx" 								>> "$file_BatoceraConf"
echo "flash.core=lightspark" 								>> "$file_BatoceraConf"
echo "flash.emulator=lightspark" 							>> "$file_BatoceraConf"
echo "msx2+.emulator=openmsx" 								>> "$file_BatoceraConf"
echo "###################################################" 				>> "$file_BatoceraConf"
echo "##  GROOVYMAME TATE SETTINGS" 							>> "$file_BatoceraConf"
echo "###################################################" 				>> "$file_BatoceraConf"
 
if [ -d "/userdata/system/configs/mame/ini" ];then
	if [ -f "/userdata/system/configs/mame/ini/horizont.ini" ];then
		rm /userdata/system/configs/mame/ini/horizont.ini
	fi
if [ -f "/userdata/system/configs/mame/ini/vertical.ini" ];then
		rm /userdata/system/configs/mame/ini/vertical.ini
	fi
fi

if [ $es_rotation_choice -eq 1 ]; then
	echo "mame.rotation=none" 							>> "$file_BatoceraConf"
	case $Rotating_screen in 
		None)
			sed -e "s/\[super_width_vertical\]/$super_width_vertical/g" -e "s/\[interlace_vertical\]/$interlace_vertical/g" -e "s/\[dotclock_min_vertical\]/$dotclock_min_vertical/g" \
				/userdata/system/Batocera-CRT-Script/Mame_configs/Mame_TATE/vertical_normal.ini > /userdata/system/configs/mame/ini/vertical.ini
		;;
		Clockwise)
			sed -e "s/\[super_width_vertical\]/$super_width_vertical/g" -e "s/\[interlace_vertical\]/$interlace_vertical/g" -e "s/\[dotclock_min_vertical\]/$dotclock_min_vertical/g" \
				  /userdata/system/Batocera-CRT-Script/Mame_configs/Mame_TATE/vertical_clockwise.ini > /userdata/system/configs/mame/ini/vertical.ini
		;;
		Counter-Clockwise)
			sed -e "s/\[super_width_vertical\]/$super_width_vertical/g" -e "s/\[interlace_vertical\]/$interlace_vertical/g" -e "s/\[dotclock_min_vertical\]/$dotclock_min_vertical/g" \
				 /userdata/system/Batocera-CRT-Script/Mame_configs/Mame_TATE/vertical_counter-clockwise.ini > /userdata/system/configs/mame/ini/vertical.ini
		;;
		*)
			echo "Problems of rotation_choice"
		;;
	esac
	echo "fbneo.video_allow_rotate=off"						>> "$file_BatoceraConf"
fi

if [ $es_rotation_choice -eq 2 ]; then
	echo "mame.rotation=autoror"							>> "$file_BatoceraConf"
	case $Rotating_screen in 
		None)	
			sed -e "s/\[super_width_horizont\]/$super_width_horizont/g" -e "s/\[interlace_horizont\]/$interlace_horizont/g" -e "s/\[dotclock_min_horizont\]/$dotclock_min_horizont/g" \
					/userdata/system/Batocera-CRT-Script/Mame_configs/Mame_TATE/horizont_inverted.ini > /userdata/system/configs/mame/ini/horizont.ini
		;;
		Clockwise)
			sed -e "s/\[super_width_horizont\]/$super_width_horizont/g" -e "s/\[interlace_horizont\]/$interlace_horizont/g" -e "s/\[dotclock_min_horizont\]/$dotclock_min_horizont/g" \
					/userdata/system/Batocera-CRT-Script/Mame_configs/Mame_TATE/horizont_counter-clockwise.ini > /userdata/system/configs/mame/ini/horizont.ini
		;;
		Counter-Clockwise)
			sed -e "s/\[super_width_horizont\]/$super_width_horizont/g" -e "s/\[interlace_horizont\]/$interlace_horizont/g" -e "s/\[dotclock_min_horizont\]/$dotclock_min_horizont/g" \
					/userdata/system/Batocera-CRT-Script/Mame_configs/Mame_TATE/horizont_clockwise.ini > /userdata/system/configs/mame/ini/horizont.ini
		;;
		*)
			echo "Problems of rotation_choice"
		;;
	esac
	echo "fbneo.video_allow_rotate=off"						>> "$file_BatoceraConf"
fi

if [ $es_rotation_choice -eq 3 ]; then
	echo "mame.rotation=none" 							>> "$file_BatoceraConf"
	case $Rotating_screen in 
		None)
			sed -e "s/\[super_width_vertical\]/$super_width_vertical/g" -e "s/\[interlace_vertical\]/$interlace_vertical/g" -e "s/\[dotclock_min_vertical\]/$dotclock_min_vertical/g" \
				/userdata/system/Batocera-CRT-Script/Mame_configs/Mame_TATE/vertical_inverted.ini > /userdata/system/configs/mame/ini/vertical.ini
		;;
		Clockwise)
			sed -e "s/\[super_width_vertical\]/$super_width_vertical/g" -e "s/\[interlace_vertical\]/$interlace_vertical/g" -e "s/\[dotclock_min_vertical\]/$dotclock_min_vertical/g" \
				/userdata/system/Batocera-CRT-Script/Mame_configs/Mame_TATE/vertical_clockwise.ini > /userdata/system/configs/mame/ini/vertical.ini
		;;
		Counter-Clockwise)
			sed -e "s/\[super_width_vertical\]/$super_width_vertical/g" -e "s/\[interlace_vertical\]/$interlace_vertical/g" -e "s/\[dotclock_min_vertical\]/$dotclock_min_vertical/g" \
				/userdata/system/Batocera-CRT-Script/Mame_configs/Mame_TATE/vertical_counter-clockwise.ini > /userdata/system/configs/mame/ini/vertical.ini      
		;;
		*)
			echo "Problems of rotation_choice"
		;;
	esac
	echo "fbneo.video_allow_rotate=off"						 >> "$file_BatoceraConf"
fi

if [ $es_rotation_choice -eq 4 ]; then
	echo "mame.rotation=autorol"							>> "$file_BatoceraConf"
	case $Rotating_screen in 
		None)
			sed -e "s/\[super_width_horizont\]/$super_width_horizont/g" -e "s/\[interlace_horizont\]/$interlace_horizont/g" -e "s/\[dotclock_min_horizont\]/$dotclock_min_horizont/g" \
				/userdata/system/Batocera-CRT-Script/Mame_configs/Mame_TATE/horizont_normal.ini > /userdata/system/configs/mame/ini/horizont.ini
		;;
		Clockwise)
			sed -e "s/\[super_width_horizont\]/$super_width_horizont/g" -e "s/\[interlace_horizont\]/$interlace_horizont/g" -e "s/\[dotclock_min_horizont\]/$dotclock_min_horizont/g" \
				/userdata/system/Batocera-CRT-Script/Mame_configs/Mame_TATE/horizont_clockwise.ini > /userdata/system/configs/mame/ini/horizont.ini
		;;
		Counter-Clockwise)
			sed -e "s/\[super_width_horizont\]/$super_width_horizont/g" -e "s/\[interlace_horizont\]/$interlace_horizont/g" -e "s/\[dotclock_min_horizont\]/$dotclock_min_horizont/g" \
				/userdata/system/Batocera-CRT-Script/Mame_configs/Mame_TATE/horizont_counter-clockwise.ini > /userdata/system/configs/mame/ini/horizont.ini
			;;
			*)
				echo "Problems of rotation_choice"
			;;
		esac
	echo "fbneo.video_allow_rotate=off" 						>> "$file_BatoceraConf"
fi
chmod 755 "$file_BatoceraConf"
