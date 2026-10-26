
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

echo
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
while true; do
  read -r monitor_choice
  if [[ "$monitor_choice" =~ ^[0-9]+$ ]] && (( monitor_choice >= 1 && monitor_choice <= ${#type_of_monitor[@]} )); then
    break
  fi
  echo -n "Invalid choice. Please enter a number between 1 and ${#type_of_monitor[@]}: "
done

monitor_firmware=${type_of_monitor[monitor_choice-1]}

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
 
 
    # Parity must follow the display engine (Calamity): DCN => even, DCE/unknown => off
    if [ "$TYPE_OF_CARD" = "AMD/ATI" ] && [ "${DISPLAY_ENGINE:-NONE}" = "DCN" ]; then
       IFE=1
    else
       IFE=0
    fi
# Log the decision for clarity
echo "Parity decision: interlace_force_even=${IFE} (engine=${DISPLAY_ENGINE}${DISPLAY_VERSION:+ ${DISPLAY_VERSION}})" \
  | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log >/dev/null

# If we couldn't read DCN/DCE (e.g., debugfs not mounted or radeon driver), note why IFE stayed 0
if [ "${DISPLAY_ENGINE:-NONE}" = "NONE" ]; then
  echo "Note: DISPLAY_ENGINE is NONE (no amdgpu_ip_info). interlace_force_even set to ${IFE}." \
    >> /userdata/system/logs/BUILD_15KHz_Batocera.log
fi

    Amd_NvidiaND_IntelDP=1
else
    # Original matrix strings
     	matrix=("arcade_15 1280x240@60 1280x480@30 1280x576@25" "arcade_15_25 1280x240@60 1280x480@30" "arcade_15_31 1280x240@60 1280x480@30" "arcade_15_25_31 1280x240@60 1280x480@30"
            	"arcade_15ex 1280x240@60 1280x480@30 1280x576@25" "arcade_25 1280x768@30 1280x800@25" "arcade_31 1280x480@60" "d9200 1280x240@60 1280x480@60" "d9400 1280x240@60 1280x480@60"
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

# monitor_info[0] is the firmware name; valid choices start at 1
max_choice=$(( ${#monitor_info[@]} - 1 ))

# Mark *x240@* boot resolutions as disabled (no usable ES theme at 240p vertical)
declare -a is_disabled=()
has_disabled_resolution=0
for ((i = 1; i <= max_choice; i++)); do
  if [[ "${monitor_info[i]}" =~ ^[0-9]+x240@ ]]; then
    is_disabled[i]=1
    has_disabled_resolution=1
  else
    is_disabled[i]=0
  fi
done

# Display monitor information
echo "	Information for monitor ${monitor_info[0]}:"

if (( has_disabled_resolution )); then
  echo "#######################################################################"
  echo "##             NOTE: 240p BOOT / ES THEME NOT SUPPORTED              ##"
  echo "##                                                                   ##"
  echo "## WHY THIS IS DISABLED                                              ##"
  echo "##  We have not found an EmulationStation theme that renders         ##"
  echo "##  correctly at 240p vertical. Choosing 240p as boot / ES           ##"
  echo "##  resolution breaks the UI; we cannot fix that in this script.     ##"
  echo "##                                                                   ##"
  echo "## WHAT THIS DOES NOT CHANGE                                         ##"
  echo "##  Switchres still resolution-switches to 240p on game launch       ##"
  echo "##  when the emulator and game support it. In-game 240p is OK.       ##"
  echo "##                                                                   ##"
  echo "## FUTURE STATE                                                      ##"
  echo "##  When a working 240p-capable EmulationStation theme exists,       ##"
  echo "##  this option will be re-enabled. Until then it stays disabled.    ##"
  echo "##                                                                   ##"
  echo "## SUPPORT POLICY                                                    ##"
  echo "##  We will not provide Discord support for 240p boot / ES issues.   ##"
  echo "##  Workarounds to force 240p are discouraged and unsupported.       ##"
  echo "##  Contributions of a working 240p EmulationStation theme are       ##"
  echo "##  very welcome.                                                    ##"
  echo "#######################################################################"
  echo ""
fi

# Display resolution options with centered alignment
for ((i = 1; i <= max_choice; i++)); do
  if (( is_disabled[i] )); then
    printf "						%s\n" "$(printf "   : %s   %b[DISABLED: 240p boot/ES theme not supported]%b" "${monitor_info[i]}" "${YELLOW}" "${NOCOLOR}")"
  else
    printf "						%s\n" "$(printf "%2d : %s" "$i" "${monitor_info[i]}")"
  fi
done

echo ""
echo "#######################################################################"
echo "##       Make your choice for the EDID Resolution                    ##"
echo "##       (Disabled entries cannot be selected.)                      ##"
echo "#######################################################################"
echo -n "                                  "

# Re-prompt until the user provides a valid number
while true; do
  read -r EDID_resolution_choice
  if [[ "$EDID_resolution_choice" =~ ^[0-9]+$ ]] && (( EDID_resolution_choice >= 1 && EDID_resolution_choice <= max_choice )); then
    if (( is_disabled[EDID_resolution_choice] == 1 )); then
      echo -n "That resolution is disabled (240p boot/ES theme not supported). Pick another number: "
      continue
    fi
    break
  fi
  echo -n "Invalid choice. Please enter a number between 1 and ${max_choice}: "
done

EDID_resolution=${monitor_info[EDID_resolution_choice]}
echo -e "				Your choice is :  ${GREEN}$EDID_resolution${NOCOLOR}"

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

# --- Decide whether the EDID itself should be generated with +1 horizontal ---
# Default: no pre-bump (nounset-safe)
_EDID_PRE_BUMP=1

# Normalize casing once
_TC_NORM="${TYPE_OF_CARD^^}"
_DRV_NORM="${Drivers_Nvidia_CHOICE^^}"

# Apply pre-bump for vendors where we want the EDID itself to carry +1 width
# (NVIDIA proprietary + nouveau, AMD/APU, Intel)
if [[ ( "$_TC_NORM" == "NVIDIA" && ( "$_DRV_NORM" == "NVIDIA_DRIVERS" || "$_DRV_NORM" == "NOUVEAU" ) ) \
   || "$_TC_NORM" == "AMD" || "$_TC_NORM" == "AMD/ATI" \
   || "$_TC_NORM" == "INTEL" ]]; then
  H_RES_EDID=$(( H_RES_EDID + 1 ))
  _EDID_PRE_BUMP=1
  echo "DEBUG: EDID PRE-bump applied; EDID will be generated at ${H_RES_EDID}x${V_RES_EDID}" \
    | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log >/dev/null
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
echo "EDID build: switchres $H_RES_EDID $V_RES_EDID $FREQ_EDID -f $FORCED_EDID -i switchres.ini -e  (IFE=$IFE, engine=${DISPLAY_ENGINE}${DISPLAY_VERSION:+ ${DISPLAY_VERSION}})" \
  | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log >/dev/null

Name_monitor_EDID+=".bin"

mkdir -p /lib/firmware/edid

patch_edid=$(pwd)
cp $patch_edid/$Name_monitor_EDID  /lib/firmware/edid/
chmod 644  /lib/firmware/edid/$Name_monitor_EDID 
rm $patch_edid/$Name_monitor_EDID   

################################################################################################################################
##  HERE FOR OTHER CARDS (AFTER CREATION OF EDID) : ADD 1 ON H RESOLUTION (EmulationStation)
##  TO AVOID THE CONFLICT WITH GEOMETRY TOOLS FOR SAME RESOLUTION OF ES
################################################################################################################################
# Normalize for case/wording differences across the script (AMD vs AMD/ATI casing, nouveau casing, etc.)
_TC_NORM="${TYPE_OF_CARD^^}"
_DRV_NORM="${Drivers_Nvidia_CHOICE^^}"

echo "DEBUG: EDID post-adjust check -> TYPE_OF_CARD='${TYPE_OF_CARD}' (norm='${_TC_NORM}'), Drivers_Nvidia_CHOICE='${Drivers_Nvidia_CHOICE}' (norm='${_DRV_NORM}'), H_RES_EDID(before)=${H_RES_EDID}" \
  | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log >/dev/null

# If we already pre-bumped for the EDID file, skip the post-bump (prevents double +1)
if (( _EDID_PRE_BUMP )); then
  echo "DEBUG: Skipping post-EDID bump because pre-bump was applied; H_RES_EDID=${H_RES_EDID}" \
    | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log >/dev/null
else
  # Apply +1 for: NVIDIA (NOUVEAU only), AMD (any spelling), and INTEL
  # Proprietary NVIDIA is handled earlier (pre-EDID block), so we exclude it here.
  if [[ ( "${_TC_NORM}" == "NVIDIA" && "${_DRV_NORM}" == "NOUVEAU" ) \
     || "${_TC_NORM}" == "AMD" || "${_TC_NORM}" == "AMD/ATI" \
     || "${_TC_NORM}" == "INTEL" ]]; then
    H_RES_EDID=$(( H_RES_EDID + 1 ))
    echo "DEBUG: Post-EDID bump applied; H_RES_EDID(after)=${H_RES_EDID}" \
      | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log >/dev/null
  else
    echo "DEBUG: No post-EDID bump for (${_TC_NORM}/${_DRV_NORM}); H_RES_EDID remains ${H_RES_EDID}" \
      | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log >/dev/null
  fi
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
