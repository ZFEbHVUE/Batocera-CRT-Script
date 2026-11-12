# Batocera-CRT-Script v44 - step 13: monitor edid
# Monitor profile and EDID resolution, switchres EDID (/lib/firmware/edid), modeline and
# videomodes.conf -> monitor_firmware, H_RES_EDID x V_RES_EDID, RES_EDID, Resolution_es, MODELINE_CUSTOM.
CRT_Freq="15KHz"
stage_begin /etc/switchres.ini || { echo "CRT EDID staging failed." >&2; exit 1; }
echo
declare -a type_of_monitor=( "generic_15" "ntsc" "pal" "arcade_15" "arcade_15ex" "arcade_25" "arcade_31" \
				"arcade_15_25" "arcade_15_31" "arcade_15_25_31" "vesa_480" "vesa_600" "vesa_768" "vesa_1024" \
				"pc_31_120" "pc_70_120" "h9110" "polo" "pstar" "k7000" "k7131" "d9200" "d9400" "d9800" \
				"m2929" "m3129" "ms2930" "ms929" "r666b" )
categories=( "Generic CRT standards 15 KHz" "Arcade fixed frequency 15 KHz" "Arcade fixed frequency 25/31KHz" \
	    			"Arcade multisync 15/25/31 KHz" "VESA GTF" "PC monitor 120 Hz" "Hantarex" "Wells Gardner" "Makvision" \
	    			"Wei-Ya" "Nanao" "Rodotron")
declare -A monitor_categories; monitor_categories["Generic CRT standards 15 KHz"]="generic_15 ntsc pal"
monitor_categories["Arcade fixed frequency 15 KHz"]="arcade_15 arcade_15ex"
monitor_categories["Arcade fixed frequency 25/31KHz"]="arcade_25 arcade_31"
monitor_categories["Arcade multisync 15/25/31 KHz"]="arcade_15_25 arcade_15_31 arcade_15_25_31"
monitor_categories["VESA GTF"]="vesa_480 vesa_600 vesa_768 vesa_1024"
monitor_categories["PC monitor 120 Hz"]="pc_31_120 pc_70_120"; monitor_categories["Hantarex"]="h9110 polo pstar"
monitor_categories["Wells Gardner"]="k7000 k7131 d9200 d9400 d9800"; monitor_categories["Makvision"]="m2929"
monitor_categories["Wei-Ya"]="m3129"; monitor_categories["Nanao"]="ms2930 ms929"; monitor_categories["Rodotron"]="r666b"
CRT_KEEP_GEOMETRY=0
CRT_GEOMETRY_SNAPSHOT="$STAGE_ORIGINAL_SWITCHRES"
CRT_GEOMETRY_RANGES=""
monitor_firmware=""
log_file="/userdata/system/logs/BootRes.log"
_crt_monitor_now=$(awk '/^[[:space:]]*monitor[[:space:]]+/ { print $2; exit }' /etc/switchres.ini 2>/dev/null || true)
if [ "$_crt_monitor_now" = "custom" ]; then
  CRT_GEOMETRY_RANGES=$(awk '/^[[:space:]]*crt_range[0-9]+[[:space:]]+/ && $2 != "auto" { print $1 "  " $2 }' /etc/switchres.ini)
  echo ""
  echo "A custom monitor profile is already saved."
  echo "That profile holds your geometry adjustments."
  echo "Switchres uses those ranges while the monitor line says custom."
  if [ -n "$CRT_GEOMETRY_RANGES" ]; then
    printf '%s\n' "$CRT_GEOMETRY_RANGES"
  else
    echo "No custom range lines were found."
  fi
  echo ""
  echo "1  Keep this geometry"
  echo "2  Pick a new monitor profile"
  echo -n "                                  "
  while true; do
    read -r _geo_choice
    case "${_geo_choice:-}" in
      1) CRT_KEEP_GEOMETRY=1; monitor_firmware="custom"; echo "Geometry: Keep"; break ;;
      2) CRT_KEEP_GEOMETRY=0; echo "Geometry: Pick a new monitor profile"; break ;;
      *) echo -n "Enter 1 or 2: " ;;
    esac
  done
  echo "Geometry choice: ${CRT_KEEP_GEOMETRY}" >> "$CRT_LOG"
fi
if [ "${CRT_KEEP_GEOMETRY}" != 1 ]; then
counter=0; b71; echo "##                     your type of monitor                          ##"; b71
for category in "${categories[@]}"; do
  echo ""; echo "	$category :"; monitors="${monitor_categories[$category]}"
  IFS=" " read -ra monitor_array <<< "$monitors"
  for i in "${!monitor_array[@]}"; do echo "						$((counter + i + 1)) : ${monitor_array[i]}"; done
  counter=$((counter + ${#monitor_array[@]}))
done
echo ""; b71
echo "##                 Make your choice for monitor type                 ##"; b71
echo -n "                                  "
while true; do
  read -r monitor_choice
  if [[ "$monitor_choice" =~ ^[0-9]+$ ]] && (( monitor_choice >= 1 && monitor_choice <= ${#type_of_monitor[@]} )); then break; fi
  echo -n "Invalid choice. Please enter a number between 1 and ${#type_of_monitor[@]}: "
done
monitor_firmware=${type_of_monitor[monitor_choice-1]}
fi
IFE=0; Amd_NvidiaND_IntelDP=0; Intel_Nvidia_NOUV=0
if ([ "$TYPE_OF_CARD" == "NVIDIA" ] && [ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]) || ([ "$TYPE_OF_CARD" == "AMD/ATI" ]) || ([ "$TYPE_OF_CARD" == "INTEL" ] && [[ $video_output == *"DP"* ]]); then
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
    if [ "$TYPE_OF_CARD" = "AMD/ATI" ] && [ "${DISPLAY_ENGINE:-NONE}" = "DCN" ]; then
       IFE=1
    else IFE=0; fi
echo "Parity decision: interlace_force_even=${IFE} (engine=${DISPLAY_ENGINE}${DISPLAY_VERSION:+ ${DISPLAY_VERSION}})" \
  | tee -a "$CRT_LOG" >/dev/null
if [ "${DISPLAY_ENGINE:-NONE}" = "NONE" ]; then
  echo "Note: DISPLAY_ENGINE is NONE (no amdgpu_ip_info). interlace_force_even set to ${IFE}." \
    >> "$CRT_LOG"
fi
    Amd_NvidiaND_IntelDP=1
else
     	matrix=("arcade_15 1280x240@60 1280x480@30 1280x576@25" "arcade_15_25 1280x240@60 1280x480@30" "arcade_15_31 1280x240@60 1280x480@30" "arcade_15_25_31 1280x240@60 1280x480@30"
            	"arcade_15ex 1280x240@60 1280x480@30 1280x576@25" "arcade_25 1280x768@30 1280x800@25" "arcade_31 1280x480@60" "d9200 1280x240@60 1280x480@60" "d9400 1280x240@60 1280x480@60"
            	"d9800 1280x240@60 1280x480@60" "generic_15 1280x240@60 1280x480@30 1280x576@25" "h9110 1280x240@60 1280x480@30" "k7000 1280x240@60 1280x480@30" "k7131 1280x240@60 1280x480@30"
            	"m2929 1280x480@60" "m3129 1280x240@60 1280x480@60" "ms2930 1280x240@60 1280x480@60" "ms929 1280x240@60 1280x480@60" "ntsc 1280x240@60 1280x480@60" "pal 1280x240@60 1280x480@60"
            	"pc_31_120 1280x240@60 1280x480@60" "pc_70_120 1280x240@60 1280x480@60" "polo 1280x240@60 1280x480@60" "pstar 1280x240@60 1280x480@60" "r666b 1280x240@60 1280x480@60"
            	"vesa_480 1280x480@60" "vesa_600 1280x480@60" "vesa_768 1280x480@60" "vesa_1024 1280x480@60")
    Intel_Nvidia_NOUV=1
fi
monitor_firmware_info=""
resolution_profile="$monitor_firmware"
[ "${CRT_KEEP_GEOMETRY}" = 1 ] && resolution_profile="generic_15"
for line in "${matrix[@]}"; do
  if [[ "$line" == "$resolution_profile"* ]]; then
   monitor_firmware_info="$line"
    break
  fi
done
if [ -z "$monitor_firmware_info" ]; then
  echo "monitor_firmware_info=Monitor firmware not found in the matrix."; exit 1
fi
IFS=' ' read -ra monitor_info <<< "$monitor_firmware_info"
max_choice=$(( ${#monitor_info[@]} - 1 ))
declare -a is_disabled=()
has_disabled_resolution=0
for ((i = 1; i <= max_choice; i++)); do
  if [[ "${monitor_info[i]}" =~ ^[0-9]+x240@ ]]; then
    is_disabled[i]=1; has_disabled_resolution=1
  else is_disabled[i]=0; fi
done
if [ "${CRT_KEEP_GEOMETRY}" = 1 ]; then
  echo "	Boot resolutions while keeping custom geometry:"
else
  echo "	Information for monitor ${monitor_info[0]}:"
fi
if (( has_disabled_resolution )); then
  b71; echo "##             NOTE: 240p BOOT / ES THEME NOT SUPPORTED              ##"; e71
  echo "## WHY THIS IS DISABLED                                              ##"
  echo "##  We have not found an EmulationStation theme that renders         ##"
  echo "##  correctly at 240p vertical. Choosing 240p as boot / ES           ##"
  echo "##  resolution breaks the UI; we cannot fix that in this script.     ##"; e71
  echo "## WHAT THIS DOES NOT CHANGE                                         ##"
  echo "##  Switchres still resolution-switches to 240p on game launch       ##"
  echo "##  when the emulator and game support it. In-game 240p is OK.       ##"; e71
  echo "## FUTURE STATE                                                      ##"
  echo "##  When a working 240p-capable EmulationStation theme exists,       ##"
  echo "##  this option will be re-enabled. Until then it stays disabled.    ##"; e71
  echo "## SUPPORT POLICY                                                    ##"
  echo "##  We will not provide Discord support for 240p boot / ES issues.   ##"
  echo "##  Workarounds to force 240p are discouraged and unsupported.       ##"
  echo "##  Contributions of a working 240p EmulationStation theme are       ##"
  echo "##  very welcome.                                                    ##"; b71; echo ""
fi
for ((i = 1; i <= max_choice; i++)); do
  if (( is_disabled[i] )); then
    printf "						%s\n" "$(printf "   : %s   %b[DISABLED: 240p boot/ES theme not supported]%b" "${monitor_info[i]}" "${YELLOW}" "${NOCOLOR}")"
  else printf "						%s\n" "$(printf "%2d : %s" "$i" "${monitor_info[i]}")"; fi
done
echo ""; b71; echo "##       Make your choice for the EDID Resolution                    ##"
echo "##       (Disabled entries cannot be selected.)                      ##"; b71
echo -n "                                  "
while true; do
  read -r EDID_resolution_choice
  if [[ "$EDID_resolution_choice" =~ ^[0-9]+$ ]] && (( EDID_resolution_choice >= 1 && EDID_resolution_choice <= max_choice )); then
    if (( is_disabled[EDID_resolution_choice] == 1 )); then
      echo -n "That resolution is disabled (240p boot/ES theme not supported). Pick another number: "; continue
    fi
    break
  fi
  echo -n "Invalid choice. Please enter a number between 1 and ${max_choice}: "
done
EDID_resolution=${monitor_info[EDID_resolution_choice]}
echo -e "				Your choice is :  ${GREEN}$EDID_resolution${NOCOLOR}"
CRT_BOOTRES_MONITOR_TYPE="$monitor_firmware"
# Keep the original base monitor identity used by the Geometry tool when
# preserving an already calibrated monitor custom profile.
if [ "${CRT_KEEP_GEOMETRY:-0}" = 1 ] && [ -r "$log_file" ]; then
  _crt_prior_monitor=$(sed -n 's/^Monitor Type: //p' "$log_file" | head -n 1)
  case "$_crt_prior_monitor" in
    ''|custom|*[!A-Za-z0-9_-]*) ;;
    *) CRT_BOOTRES_MONITOR_TYPE="$_crt_prior_monitor" ;;
  esac
fi
{
    echo "Monitor Type: $CRT_BOOTRES_MONITOR_TYPE"; echo "Boot Resolution: $EDID_resolution"
} > "$STAGE_BOOTRES"

IFS="x@ " read -r H_RES_EDID V_RES_EDID FREQ_EDID <<< "$EDID_resolution"
if ([ "$TYPE_OF_CARD" == "NVIDIA" ] && [ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]); then H_RES_EDID=$((H_RES_EDID+1)); fi
RES_EDID="${H_RES_EDID}x${V_RES_EDID}"
if [ "$FREQ_EDID" == "50" ] || [ "$FREQ_EDID" == "60" ]; then
	RES_EDID_SCANNING="${H_RES_EDID}x${V_RES_EDID}p"
elif [ "$FREQ_EDID" == "25" ] || [ "$FREQ_EDID" == "30" ]; then
	RES_EDID_SCANNING="${H_RES_EDID}x${V_RES_EDID}i"
else echo "problems of frame rate to determine progressif or interlace"; fi
_EDID_PRE_BUMP=1; _TC_NORM="${TYPE_OF_CARD^^}"; _DRV_NORM="${Drivers_Nvidia_CHOICE^^}"
if [[ ( "$_TC_NORM" == "NVIDIA" && ( "$_DRV_NORM" == "NVIDIA_DRIVERS" || "$_DRV_NORM" == "NOUVEAU" ) ) \
   || "$_TC_NORM" == "AMD" || "$_TC_NORM" == "AMD/ATI" \
   || "$_TC_NORM" == "INTEL" ]]; then
  H_RES_EDID=$(( H_RES_EDID + 1 ))
  _EDID_PRE_BUMP=1
  echo "DEBUG: EDID PRE-bump applied; EDID will be generated at ${H_RES_EDID}x${V_RES_EDID}" \
    | tee -a "$CRT_LOG" >/dev/null
fi
FORCED_EDID="${H_RES_EDID}x${V_RES_EDID}@${FREQ_EDID}"; Name_monitor_EDID=$monitor_firmware
sed -i "s/.*monitor         .*/        monitor                   $Name_monitor_EDID/" "$STAGE_WORK_SWITCHRES"
DOTCLOCK_MIN_SWITCHRES=0
sed -i "s/.*dotclock_min        .*/    dotclock_min              $DOTCLOCK_MIN_SWITCHRES/" "$STAGE_WORK_SWITCHRES"
sed -i "s/.*interlace_force_even   .*/        interlace_force_even      $IFE/" "$STAGE_WORK_SWITCHRES"
if ! ( cd "$STAGE_DIR" && { if declare -F diag_run >/dev/null 2>&1; then diag_run 13_monitor_edid edid_generation switchres "$H_RES_EDID" "$V_RES_EDID" "$FREQ_EDID" -f "$FORCED_EDID" -i "$STAGE_WORK_SWITCHRES" -e > /dev/null 2>/dev/null; else switchres "$H_RES_EDID" "$V_RES_EDID" "$FREQ_EDID" -f "$FORCED_EDID" -i "$STAGE_WORK_SWITCHRES" -e > /dev/null 2>/dev/null; fi; } ); then
  echo "Switchres EDID generation failed; no existing configuration changed." >&2; exit 1
fi
echo "EDID build: switchres $H_RES_EDID $V_RES_EDID $FREQ_EDID -f $FORCED_EDID -i switchres.ini -e  (IFE=$IFE, engine=${DISPLAY_ENGINE}${DISPLAY_VERSION:+ ${DISPLAY_VERSION}})" \
  | tee -a "$CRT_LOG" >/dev/null
Name_monitor_EDID+=".bin"
STAGE_EDID="$STAGE_DIR/$Name_monitor_EDID"
if ! stage_valid_edid "$STAGE_EDID"; then
  echo "Switchres produced an invalid EDID; no existing configuration changed." >&2; exit 1
fi
if declare -F diag_probe >/dev/null 2>&1; then diag_probe 13_monitor_edid staged_edid_valid "$STAGE_EDID"; fi
_TC_NORM="${TYPE_OF_CARD^^}"; _DRV_NORM="${Drivers_Nvidia_CHOICE^^}"
echo "DEBUG: EDID post-adjust check -> TYPE_OF_CARD='${TYPE_OF_CARD}' (norm='${_TC_NORM}'), Drivers_Nvidia_CHOICE='${Drivers_Nvidia_CHOICE}' (norm='${_DRV_NORM}'), H_RES_EDID(before)=${H_RES_EDID}" \
  | tee -a "$CRT_LOG" >/dev/null
if (( _EDID_PRE_BUMP )); then
  echo "DEBUG: Skipping post-EDID bump because pre-bump was applied; H_RES_EDID=${H_RES_EDID}" \
    | tee -a "$CRT_LOG" >/dev/null
else
  if [[ ( "${_TC_NORM}" == "NVIDIA" && "${_DRV_NORM}" == "NOUVEAU" ) \
     || "${_TC_NORM}" == "AMD" || "${_TC_NORM}" == "AMD/ATI" \
     || "${_TC_NORM}" == "INTEL" ]]; then
    H_RES_EDID=$(( H_RES_EDID + 1 ))
    echo "DEBUG: Post-EDID bump applied; H_RES_EDID(after)=${H_RES_EDID}" \
      | tee -a "$CRT_LOG" >/dev/null
  else
    echo "DEBUG: No post-EDID bump for (${_TC_NORM}/${_DRV_NORM}); H_RES_EDID remains ${H_RES_EDID}" \
      | tee -a "$CRT_LOG" >/dev/null
  fi
fi
MODE=$(switchres "$H_RES_EDID" "$V_RES_EDID" "$FREQ_EDID" -f "$FORCED_EDID" -i "$STAGE_WORK_SWITCHRES" -c)
MODELINE_PARAMETERS=$(echo "$MODE" | sed -n 's/.*Modeline "[^"]*" \([0-9.]\+\) \([0-9 ]\+\) \(.*\)/\1 \2 \3/p')
read -r Pixel_Clock H_res HF_Porch H_Sync HB_Porch V_res VF_Porch V_Sync VB_Porch Inter HSync VSync <<< "$MODELINE_PARAMETERS"
if [[ "$MODELINE_PARAMETERS" == *"interlace"* ]]; then
    Interlace=2
else Interlace=1; fi
Frame_Rate=$(echo "$(echo "$(echo "$Pixel_Clock*1000000" | bc -l)/$(($((H_res+$((HB_Porch-H_res))))*$((V_res+$((VB_Porch-V_res))))))" | bc -l)*$Interlace" | bc -l)
Frame_Rate=$(printf "%.2f" $Frame_Rate)
Resolution_es=""es.resolution=""${H_RES_EDID}"x"${V_RES_EDID}"."${Frame_Rate}"000"
MODELINE_CUSTOM="\"${RES_EDID}\" $(echo "$MODE" | sed -n 's/.*Modeline "[^"]*" \([0-9.]\+\) \([0-9 ]\+\) \(.*\)/\1 \2 \3/p')"
monitor_name_MAME=$monitor_firmware; echo "monitor mame = $monitor_name_MAME" >> "$CRT_LOG"
Name_VideoModes="videomodes.conf_"$monitor_firmware
if [ "${CRT_KEEP_GEOMETRY}" = 1 ]; then Name_VideoModes="videomodes.conf_generic_15"; fi
boot_resolution="e"
echo -n -e "                       PRESS ${BLUE}ENTER${NOCOLOR} TO CONTINUE "; read; echo
