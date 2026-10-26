########################################################################################
#####################              BOOT RESOLUTION        ##############################
########################################################################################
boot_resolution="e"
#echo "Boot resolution = $boot_resolution" >> /userdata/system/logs/BUILD_15KHz_Batocera.log
################################################################################################################################
#####################              ES RESOLUTION          ######################################################################

################################################################################################################################
#echo "ES_resolution = $ES_resolution" >> /userdata/system/logs/BUILD_15KHz_Batocera.log

################################################################################################################################
#######################################                  ROTATION                   ############################################
################################################################################################################################
echo -n -e "                       PRESS ${BLUE}ENTER${NOCOLOR} TO CONTINUE "
read
echo
echo ""
echo "#######################################################################"
echo "##                          ROTATING SCREEN                          ##"
echo "##                                                                   ##"
echo "##       SET THE ACTUAL PHYSICAL ORIENTATION OF YOUR MONITOR         ##"
echo "##         AND THE DIRECTION OF ROTATION (HORIZONTAL ↔ VERTICAL)     ##"
echo "##                                                                   ##"
echo "##   If you use your monitor normally (no physical rotation),        ##"
echo "##   select: NONE                                                    ##"
echo "##                                                                   ##"
echo "##                           IMPORTANT                               ##"
echo "##                                                                   ##"
echo "##   ┌──────────────────────────────┐                                 ##"
echo "##   │        EMULATOR NOTES        │                                 ##"
echo "##   └──────────────────────────────┘                                 ##"
echo "##                                                                   ##"
echo "##   ● MAME (GroovyMAME): Works for all horizontal and vertical       ##"
echo "##     games automatically on any screen orientation.                ##"
echo "##                                                                   ##"
echo "##   ● FBNeo:                                                        ##"
echo "##       - Horizontal screen → Horizontal games (no rotation)        ##"
echo "##                              Vertical games (rotated)             ##"
echo "##       - Vertical screen   → Horizontal games (rotated)            ##"
echo "##                              Vertical games (no rotation)         ##"
echo "##                                                                   ##"
echo "##   ● Libretro cores: Works for all horizontal games.               ##"
echo "##     Some TATE (vertical) modes may have rotation issues.          ##"
echo "##                                                                   ##"
echo "##   ● Standalone emulators: Works for horizontal games on           ##"
echo "##     rotated screens. Some vertical modes may show bugs.           ##"
echo "##                                                                   ##"
echo "##   ● Future Pinball: Works correctly in both horizontal and         ##"
echo "##     vertical (portrait) display modes.                            ##"
echo "##                                                                   ##"
echo "##   These options allow you to play classic horizontal games on     ##"
echo "##   vertical monitors — with or without rotation — across           ##"
echo "##   various emulators. Remember: by default, emulators run          ##"
echo "##   in horizontal mode (no rotation).                               ##"
echo "##                                                                   ##"
echo "##   Only GroovyMAME automatically detects whether a game is         ##"
echo "##   horizontal or vertical and adjusts rotation accordingly.        ##"
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
echo "##                     EMULATIONSTATION ORIENTATION                  ##"
echo "##                  MONITOR SETUP (FROM HORIZONTAL)                  ##"
echo "##                                                                   ##"
echo "##  HORIZONTAL (Default)             →  NORMAL     (0°)              ##"
echo "##  VERTICAL (Counter-Clockwise)     →  TATE90     (90°)             ##"
echo "##  HORIZONTAL (Upside Down)         →  INVERTED   (180°)            ##"
echo "##  VERTICAL (Clockwise)             →  TATE270    (270° or -90°)    ##"
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
echo "##              Select your EmulationStation orientation             ##"
echo "##        (Choose the position that matches your monitor setup)      ##"
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
		video_display=$video_output
		nbr=$(sed 's/[^[:digit:]]//g' <<< "${video_output}")
		video_modeline=$video_output_xrandr
	elif [[ $video_output == *"DVI"* ]]; then
		nbr=$(sed 's/[^[:digit:]]//g' <<< "${video_output}")
		video_display=$video_output
	
  		term_DVI=DVI-I
		if [ "$R9_380" == "YES" ]; then
			video_modeline=$video_output_xrandr
		else
			video_modeline=$video_output_xrandr
		fi	
  
	elif [[ "$video_output" == *"VGA"* ]]; then
		term_VGA=VGA
		nbr=$(sed 's/[^[:digit:]]//g' <<< "${video_output}")
		video_display=$video_output
		video_modeline=$video_output_xrandr
	elif [[ "$video_output" == *"HDMI"* ]] ; then
		term_HDMI=HDMI-A
		nbr=$(sed 's/[^[:digit:]]//g' <<< "${video_output}")
		video_display=$video_output
 		video_modeline=$video_output_xrandr
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
		video_modeline=$video_output_xrandr   
		dotclock_min=0
		dotclock_min_mame=$dotclock_min
		super_width=1920
		super_width_mame=$super_width
	elif [[ "$video_output" == *"VGA"* ]]; then
		term_VGA="VGA"
		nbr=$(sed 's/[^[:digit:]]//g' <<< "${video_output}")
		video_display=$video_output
		video_modeline=$video_output_xrandr
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
			if [ "$Drivers_Name_Nvidia_CHOICE" == "legacy470" ]; then
				video_modeline=$video_output_xrandr
				dotclock_min=0
				dotclock_min_mame=$dotclock_min
				super_width=3840
				super_width_mame=$super_width
			else
				video_modeline=$video_output_xrandr 
				dotclock_min=0
				dotclock_min_mame=$dotclock_min
				super_width=3840
				super_width_mame=$super_width
			fi
		else	
			video_modeline=$video_output_xrandr 
			dotclock_min=0
			super_width=3840
			super_width_mame=$super_width
		fi
	elif [[ "$video_output" == *"DVI"* ]]; then
		term_DVI=DVI-I
		nbr=$(sed 's/[^[:digit:]]//g' <<< "${video_output}")
		video_display=$video_output
		if [ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]; then
			if [ "$Drivers_Name_Nvidia_CHOICE" == "legacy470" ]; then
				video_modeline=$video_output_xrandr
				dotclock_min=25
				dotclock_min_mame=$dotclock_min
				super_width=3840
				super_width_mame=$super_width
			else
				video_modeline=$video_output_xrandr
				dotclock_min=0
				dotclock_min_mame=$dotclock_min
				super_width=3840
				super_width_mame=$super_width
			fi
		else
			video_modeline=$video_output_xrandr
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
			if [ "$Drivers_Name_Nvidia_CHOICE" == "legacy470" ]; then	
				video_modeline=$video_output_xrandr
				dotclock_min=25.0
				dotclock_min_mame=$dotclock_min
				super_width=3840
				super_width_mame=$super_width
			else
				video_modeline=$video_output_xrandr
			 	dotclock_min=25.0
				dotclock_min_mame=$dotclock_min
				super_width=3840
				super_width_mame=$super_width
			fi
		else
			video_modeline=$video_output_xrandr
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
			if [ "$Drivers_Name_Nvidia_CHOICE" == "legacy470" ]; then	
				video_modeline=$video_output_xrandr
				dotclock_min=25.0
				dotclock_min_mame=$dotclock_min
				super_width=3840
				super_width_mame=$super_width
			else
				video_modeline=$video_output_xrandr
				dotclock_min=25.0
				dotclock_min_mame=$dotclock_min
				super_width=3840
				super_width_mame=$super_width
			fi
		else
			video_modeline=$video_output_xrandr
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
echo
echo "#######################################################################"
echo "##                                                                   ##"
echo "##                      ADVANCED CONFIGURATION                       ##"
echo "##                                                                   ##"
echo "##                 Experimental display tuning options               ##"
echo "##                                                                   ##"
echo "##                        • Minimum Dotclock                         ##"
echo "##                        • Super-Resolution                         ##"
echo "##                                                                   ##"
echo "##     (If you are unsure about these settings, just press ENTER)    ##"
echo "##                                                                   ##"
echo "#######################################################################"
echo ""
declare -a Default_DT_SR_choice=( "YES" "NO" ) 
for var in "${!Default_DT_SR_choice[@]}" ; do echo "			$((var+1)) : ${Default_DT_SR_choice[$var]}"  | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log; done
echo ""
echo "#######################################################################"
echo "##     Do you want to enter the advanced configuration menu?         ##" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
echo "##                                                                   ##"
echo "##  Recommended only for experienced users or troubleshooting cases. ##"
echo "##       If unsure, it’s best to skip this step and press ENTER.     ##"
echo "#######################################################################"
echo -n "                                  "
read choice_DT_SR
while [[ ! ${choice_DT_SR} =~ ^[1-$((var+1))]$ ]] && [[ "$choice_DT_SR" != "" ]] ; do
	echo -n "Select option 1 to $((var+1)) or ENTER to bypass this configuration:"
	read choice_DT_SR
done

# ---- FIX: ensure DT_SR_Choice is always defined (ENTER or '2' -> NO) ----
DT_SR_Choice="NO"

if [[ -z "$choice_DT_SR" || $choice_DT_SR = "2" ]] ; then 
	echo "                    your choice is : Skipping advanced configuration (using defaults)."  | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
else 
	DT_SR_Choice=${Default_DT_SR_choice[$choice_DT_SR-1]}
echo -e "                    your choice is :${GREEN} $DT_SR_Choice ${NOCOLOR}"  | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
fi


if [ "$DT_SR_Choice" == "YES" ] ; then
	echo -n -e "                       PRESS ${BLUE}ENTER${NOCOLOR} TO CONTINUE "
	read
	echo
	echo ""
	echo "#######################################################################"
	echo "##                                                                   ##"
	echo "##                      ADVANCED CONFIGURATION       1/3             ##" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
	echo "##                                                                   ##"
	echo "##                   Minimum Dotclock Configuration                  ##"
	echo "##                                                                   ##"
	echo "##  This setting defines the lowest pixel clock (MHz) your GPU can   ##"
	echo "##  use when generating video modes. In most cases, this value can   ##"
	echo "##  safely remain at 0 MHz.                                          ##"
	echo "##                                                                   ##"
	echo "##  ⚠️  For AMD GPUs (and most Nvidia Maxwell cards), setting a       ##"
	echo "##  minimum dotclock manually is almost never required.              ##"
	echo "##  The hardware already supports a low dotclock of 0 MHz by design. ##"
	echo "##                                                                   ##"
	echo "##  Only adjust this if you are experiencing launch issues in        ##"
	echo "##  certain emulators or cores (e.g., NES, PC Engine) that display   ##"
	echo "##  a black screen due to unsupported timing.                        ##"
	echo "##                                                                   ##"
	echo "##  If you are unsure, leave this unchanged and just press ENTER.    ##"
	echo "##                                                                   ##"
	echo "#######################################################################"

	echo ""
	declare -a dcm_selector=( "Low - 0" "Mild - 6" "Medium - 12" "High - 25" "CUSTOM")
	for var in "${!dcm_selector[@]}" ; do echo "			$((var+1)) : ${dcm_selector[$var]}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log; done
	echo ""
	echo "#######################################################################"
	echo "##                Choose a minimum dotclock threshold                ##"
	echo "##      This defines the lowest pixel clock allowed for modes.       ##"
	echo "##           Press ENTER to keep the default value of 0 MHz.         ##"
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
				echo "##                                                                   ##"
				echo "##         Enter your custom minimum dotclock value (0–25 MHz)       ##"
				echo "##       Only change this if you know your hardware’s limits.        ##"
				echo "##  (Used to restrict the lowest pixel clock allowed by modelines)   ##"
				echo "##         If unsure, use the default value (0 MHz).                 ##"
				echo "##                                                                   ##"
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
monitor_MAME_CHOICE=${monitor_MAME_CHOICE:-NO}
	if [ "$monitor_MAME_CHOICE" = "YES" ] ; then
		echo ""
		echo "#######################################################################"
		echo "##                                                                   ##"
		echo "##                      ADVANCED CONFIGURATION       1b/3            ##" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
		echo "##                                                                   ##"
		echo "##                           MAME MONITOR                            ##"
		echo "##                                                                   ##"
		echo "##  This section adjusts the minimum dotclock used by MAME only.     ##"
		echo "##  In most setups you should leave this unchanged.                   ##"
		echo "##  Change it only if some games/cores launch to a black screen.     ##"
		echo "##                                                                   ##"
		echo "##              ==  MAME minimum dotclock selector  ==               ##"
		echo "##                                                                   ##"
		echo "##  Press ENTER to keep the same dotclock_min as the main monitor.   ##"
		echo "##  If you know what you are doing, select a different value below.  ##"
		echo "##                                                                   ##"
		echo "#######################################################################"
 		echo ""
		declare -a dcm_m_selector=( "Low - 0" "Mild - 6" "Medium - 12" "High - 25" "CUSTOM")
		for var in "${!dcm_m_selector[@]}" ; do echo "			$((var+1)) : ${dcm_m_selector[$var]}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log; done
		echo ""
		echo "#######################################################################"
		echo "##           Select your preferred MAME minimum dotclock value       ##"
		echo "##        (Press ENTER to keep the same as your main monitor)        ##"
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
			echo -e "                    your choice is :${GREEN}  ${dcm_m_selector[$dcm_m-1]}${NOCOLOR}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
			case $dcm_m in
				1)	dotclock_min_mame=0;;
				2)	dotclock_min_mame=6;;
				3)	dotclock_min_mame=12;;
				4)	dotclock_min_mame=25;;
				5) 	echo "#######################################################################"
					echo "##     Enter your custom MAME minimum dotclock value (0–25 MHz)      ##" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
					echo "##     Only change this if you understand your hardware limits.      ##" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
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
	echo "##                     ==  Super-Resolution  ==                      ##"
	echo "##                                                                   ##"
	echo "##      This option defines the virtual width used by Switchres.     ##"
	echo "##     It helps reduce video mode changes between different games.   ##"
	echo "##                                                                   ##"
	echo "##     You can select a default value recommended for your GPU, or   ##"
	echo "##        specify a custom one (advanced users only).                ##"
	echo "##                                                                   ##"
	echo "##     If you are unsure, simply press ENTER to use the default.     ##"
	echo "##                                                                   ##"
	echo "#######################################################################"
	echo ""
	declare -a sr_selector=( "1920 - Intel default" "2560 - amd/ati default" "3840 - nvidia default" "CUSTOM (experimental)")
	for var in "${!sr_selector[@]}" ; do echo "			$((var+1)) : ${sr_selector[$var]}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log; done
	echo ""
	echo "#######################################################################"
	echo "##               Select your preferred super-resolution              ##"
	echo "##          (Press ENTER to skip this configuration step)            ##"
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
				echo "##           Enter a valid number between 0 and 25 MHz               ##"
				echo "##       for your custom super-resolution minimum dotclock.          ##"
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
monitor_MAME_CHOICE=${monitor_MAME_CHOICE:-NO}
	if [ "$monitor_MAME_CHOICE" = "YES" ] ; then
		echo ""
		echo "#######################################################################"
		echo "##                                                                   ##"
		echo "##                      ADVANCED CONFIGURATION       2b/3            ##" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
		echo "##                                                                   ##"
		echo "##                    ==     MAME Super-Resolution     ==             ##"
		echo "##                                                                   ##"
		echo "##     This option defines the vertical super-resolution used by      ##"
		echo "##     MAME when generating dynamic modelines for arcade games.       ##"
		echo "##     You can choose a recommended preset or define your own         ##"
		echo "##     custom value for testing and fine-tuning purposes.             ##"
		echo "##                                                                   ##"
		echo "##     In most cases, the default value for your GPU is optimal.      ##"
		echo "##     If you are unsure what this means, simply press ENTER to       ##"
		echo "##     keep the default setting.                                      ##"
		echo "##                                                                   ##"
		echo "#######################################################################"
		echo ""
		declare -a sr_m_selector=( "1920 - Intel default" "2560 - amd/ati/ default" "3840 - nvidia default" "Same as main monitor" "CUSTOM (experimental)")
		for var in "${!sr_m_selector[@]}" ; do echo "			$((var+1)) : ${sr_m_selector[$var]}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log; done
		echo ""
		echo "#######################################################################"
		echo "##     Choose a MAME super-resolution preset, or CUSTOM (width)      ##"
		echo "##           Press ENTER to keep the default for your GPU            ##"
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
