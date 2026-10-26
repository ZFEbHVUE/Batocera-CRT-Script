
#######################################################################################
#######################################################################################
##         USB Arcade Encoders (multiple choices) for Arcade cabinet 
#######################################################################################
#######################################################################################

echo ""
echo "#######################################################################"
echo "##     USB Arcade Encoder(s) :  Multiple choices are possible        ##"
echo "#######################################################################"
declare -a Encoder_inputs=\($(ls -1 /dev/input/by-id/ | tr '\012' ' ' | sed -e 's, ," ",g' -e 's,^,",' -e 's," "$,",')\)
for var in "${!Encoder_inputs[@]}"; do
  echo "			$((var+1)) : ${Encoder_inputs[$var]}"
done
echo "                        0 : Exit for USB Arcade Encoder(s)                   "
echo "#######################################################################"
echo "##                                                                   ##"
echo "##                   Select your USB Arcade Encoder(s)               ##"
echo "##                                                                   ##"
echo "##   You can select one or multiple encoders by typing their numbers ##"
echo "##   separated by commas or spaces (for example: 1 2 3).             ##"
echo "##                                                                   ##"
echo "##   If you do not have any USB Arcade Encoders, or if you want      ##"
echo "##   Batocera to handle encoder setup automatically, simply press    ##"
echo "##   ENTER or type 0 to skip this step.                              ##"
echo "##                                                                   ##"
echo "##                     RECOMMENDED: PRESS 0 OR ENTER                 ##"
echo "##                                                                   ##"
echo "#######################################################################"
echo -n "                                  "
read Encoder_choice

# Normalize input: commas → spaces; trim extra spaces
Encoder_choice="$(echo "${Encoder_choice:-}" | sed -e 's/,/ /g' -e 's/[[:space:]]\+/ /g' -e 's/^ //; s/ $//')"

if [ -z "$Encoder_choice" ] || [ "x$Encoder_choice" = "x0" ]; then
  echo "No USB Arcade encoder(s) has been chosen"
else
  RUNTIME_DIR="/userdata/system/configs/xarcade2jstick"
  LEGACY_DIR="/usr/share/batocera/datainit/system/configs/xarcade2jstick"

  # Ensure runtime directory exists
  mkdir -p "$RUNTIME_DIR"

  for i in $Encoder_choice; do
    # Guard: numeric and within bounds
    case "$i" in
      ''|*[!0-9]*) echo "Skipping invalid selection: $i"; continue ;;
    esac
    idx=$((i-1))
    if [ "$idx" -lt 0 ] || [ "$idx" -ge "${#Encoder_inputs[@]}" ]; then
      echo "Skipping out-of-range selection: $i"
      continue
    fi

    name="${Encoder_inputs[$idx]}"
    echo -e "                    your choice is : ${name}"

    # Create marker in runtime overlay
    touch "$RUNTIME_DIR/$name" 2>/dev/null || echo "Warning: could not create $RUNTIME_DIR/$name"

    # Optionally also write to legacy tree if it exists and is writable
    if [ -d "$LEGACY_DIR" ] && touch "$LEGACY_DIR/.writable_test" 2>/dev/null; then
      rm -f "$LEGACY_DIR/.writable_test"
      mkdir -p "$LEGACY_DIR"
      touch "$LEGACY_DIR/$name" 2>/dev/null || true
    fi
  done
fi




#######################################################################################
# Select the calibration resolution for your GunCon II
#######################################################################################

echo "####################################################################################"
echo "##        Configure the resolution for calibrating your GunCon2 lightgun          ##" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
echo "##                                                                                ##"
echo "##   (Recommended Default)                                                        ##"
echo "##     • For AMD/ATI or NVIDIA (Maxwell and newer):  use 320x240 @ 60 Hz          ##"
echo "##     • For older NVIDIA GPUs with dotclock_min = 25 MHz:  try 640x480 @ 60 Hz   ##"
echo "##                                                                                ##"
echo "##   Experimental Mode                                                            ##"
echo "##     • You can test custom resolutions such as 640x480 @ 60 Hz                  ##"
echo "##       or 768x576 @ 50 Hz to see what works best on your setup.                 ##"
echo "##     • If you wish to experiment, choose YES below.                             ##"
echo "##                                                                                ##"
printf "%b\n" "##   ${RED}Warning:${NOCOLOR}                                                                     ##"
echo "##   It is strongly recommended to keep the default value unless you              ##"
echo "##   fully understand how these resolutions affect calibration.                   ##"
echo "##                                                                                ##"
printf "%b\n" "##   ${GREEN}Note:${NOCOLOR}                                                                        ##"
echo "##   Calibration results are generally most accurate at 320x240p.                 ##"
echo "##                                                                                ##"
echo "##   Press ENTER to use the default calibration resolution (320x240 @ 60 Hz).     ##"
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
echo "##                   BEFORE PRESSING ENTER, PLEASE READ              ##"
echo "##                                                                   ##"
echo "##  The authors of this script take no responsibility for any damage ##"
echo "##               caused to your CRT or connected hardware.           ##"
echo "##                                                                   ##"
echo "##   Before continuing, make sure you have properly connected your   ##"
echo "##   display cables and verified that your setup supports 15 kHz.    ##"
echo "##                                                                   ##"
echo "##        Always power off your system safely before reconnecting    ##"
echo "##             or adjusting video cables and CRT displays.           ##"
echo "##                                                                   ##"
echo "##          When you’re ready, reboot Batocera and enjoy your        ##"
echo "##                        15 kHz experience!                         ##"
echo "##                                                                   ##"
echo "#######################################################################"
echo ""
echo -n -e "                       PRESS ${BLUE}ENTER${NOCOLOR} TO FINISH "
read 

