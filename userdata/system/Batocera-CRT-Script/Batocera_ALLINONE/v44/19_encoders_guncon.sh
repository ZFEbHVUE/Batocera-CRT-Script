# Batocera-CRT-Script v44 - step 19: encoders guncon
# USB arcade encoders and the GunCon2 calibration resolution.
echo ""; b71; echo "##     USB Arcade Encoder(s) :  Multiple choices are possible        ##"; b71
declare -a Encoder_inputs=\($(ls -1 /dev/input/by-id/ | tr '\012' ' ' | sed -e 's, ," ",g' -e 's,^,",' -e 's," "$,",')\)
for var in "${!Encoder_inputs[@]}"; do echo "			$((var+1)) : ${Encoder_inputs[$var]}"; done
echo "                        0 : Exit for USB Arcade Encoder(s)                   "; b71; e71
echo "##                   Select your USB Arcade Encoder(s)               ##"; e71
echo "##   You can select one or multiple encoders by typing their numbers ##"
echo "##   separated by commas or spaces (for example: 1 2 3).             ##"; e71
echo "##   If you do not have any USB Arcade Encoders, or if you want      ##"
echo "##   Batocera to handle encoder setup automatically, simply press    ##"
echo "##   ENTER or type 0 to skip this step.                              ##"; e71
echo "##                     RECOMMENDED: PRESS 0 OR ENTER                 ##"; e71; b71
echo -n "                                  "; read Encoder_choice
Encoder_choice="$(echo "${Encoder_choice:-}" | sed -e 's/,/ /g' -e 's/[[:space:]]\+/ /g' -e 's/^ //; s/ $//')"
CRT_ENCODER_NAMES=()
if [ -z "$Encoder_choice" ] || [ "x$Encoder_choice" = "x0" ]; then
  echo "No USB Arcade encoder(s) has been chosen"
else
  for i in $Encoder_choice; do
    case "$i" in
      ''|*[!0-9]*) echo "Skipping invalid selection: $i"; continue ;;
    esac
    idx=$((i-1))
    if [ "$idx" -lt 0 ] || [ "$idx" -ge "${#Encoder_inputs[@]}" ]; then
      echo "Skipping out-of-range selection: $i"; continue
    fi
    name="${Encoder_inputs[$idx]}"; echo -e "                    your choice is : ${name}"
    CRT_ENCODER_NAMES+=("$name")
  done
fi
echo "####################################################################################"
echo "##        Configure the resolution for calibrating your GunCon2 lightgun          ##" | tee -a "$CRT_LOG"
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
echo "####################################################################################"; echo ""
declare -a Calibration_Guncon2_choice=( "NO" "YES" )
for var in "${!Calibration_Guncon2_choice[@]}" ; do echo "			$((var+1)) : ${Calibration_Guncon2_choice[$var]}" | tee -a "$CRT_LOG"; done
echo ""; b71; echo "##                         Make your choice                          ##"; b71
pick choice_Calibration_Guncon2 $((var+1)) d
if [ -z "$choice_Calibration_Guncon2" ] || [ "$choice_Calibration_Guncon2" == "1" ]; then
	echo -e "                    Your choice is: ${GREEN}Bypass with default resolution (320x240@60Hz)${NOCOLOR}" | tee -a "$CRT_LOG"
	Guncon2_x=320; Guncon2_y=240; Guncon2_freq=60
	Guncon2_res=($Guncon2_x"x"$Guncon2_y)
else
	echo -e "                    Your choice is: ${GREEN}Custom resolution setup${NOCOLOR}" | tee -a "$CRT_LOG"
	echo "###############################################################################"
	echo "##      Select your custom horizontal resolution for Guncon2 calibration     ##"
	echo "###############################################################################"
	num Guncon2_x "" "Enter a valid number greater than 0 for Guncon2_x: "
	echo -e "                    CUSTOM Guncon2_x Horizontal resolution  = ${GREEN}${Guncon2_x}${NOCOLOR}" | tee -a "$CRT_LOG"
	echo "###############################################################################"
	echo "##      Select your custom vertical resolution for Guncon2 calibration       ##"
	echo "###############################################################################"
	num Guncon2_y "" "Enter a valid number greater than 0 for Guncon2_y: "
	echo -e "                    CUSTOM Guncon2_y Vertical resolution  = ${GREEN}${Guncon2_y}${NOCOLOR}" | tee -a "$CRT_LOG"
	echo "###############################################################################"
	echo "##      Select your custom frequency resolution for Guncon2 calibration      ##"
	echo "###############################################################################"
	num Guncon2_freq "" "Enter a valid number greater than 0 for Guncon2_freq: "
	echo -e "                    CUSTOM frequency resolution  = ${GREEN}${Guncon2_freq}${NOCOLOR}" | tee -a "$CRT_LOG"
	Guncon2_res=($Guncon2_x"x"$Guncon2_y)
fi
apply_encoder_selection() {
  [ "${#CRT_ENCODER_NAMES[@]}" -eq 0 ] && return 0
  local RUNTIME_DIR="/userdata/system/configs/xarcade2jstick"
  local LEGACY_DIR="/usr/share/batocera/datainit/system/configs/xarcade2jstick"
  local name
  # Selected runtime encoder markers are required; a failed touch must not
  # be masked by the next iteration or the optional legacy installation path.
  write_run 19_encoders_guncon encoder_runtime_dir mkdir -p "$RUNTIME_DIR"
  for name in "${CRT_ENCODER_NAMES[@]}"; do
    # Input names come from /dev/input/by-id; do not allow path traversal.
    case "$name" in ''|.|..|*/*) write_abort 19_encoders_guncon encoder_marker_name_unsafe 1 ;; esac
    [[ ! -L "$RUNTIME_DIR/$name" && ! -d "$RUNTIME_DIR/$name" ]] || write_abort 19_encoders_guncon encoder_marker_unsafe 1
    write_run 19_encoders_guncon encoder_runtime_marker touch "$RUNTIME_DIR/$name"
    [[ -f "$RUNTIME_DIR/$name" && ! -L "$RUNTIME_DIR/$name" ]] || write_abort 19_encoders_guncon encoder_marker_readback 1
    if [ -d "$LEGACY_DIR" ] && touch "$LEGACY_DIR/.writable_test" 2>/dev/null; then
      # The legacy data-init mirror is best effort and is not the runtime path.
      if ! rm -f "$LEGACY_DIR/.writable_test" || ! mkdir -p "$LEGACY_DIR" || ! touch "$LEGACY_DIR/$name" 2>/dev/null; then
        diag_event 19_encoders_guncon encoder_legacy_marker optional_mirror failed || :
      fi
    fi
  done
}
