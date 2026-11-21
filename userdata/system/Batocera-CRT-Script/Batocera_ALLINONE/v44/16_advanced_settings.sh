# Batocera-CRT-Script v44 - step 16: advanced settings
# Advanced configuration (custom dotclock / super-resolution) and USB polling rate.
b71; e71; echo "##                      ADVANCED CONFIGURATION                       ##"; e71
echo "##                 Experimental display tuning options               ##"; e71
echo "##                        • Minimum Dotclock                         ##"
echo "##                        • Super-Resolution                         ##"; e71
echo "##     (If you are unsure about these settings, just press ENTER)    ##"; e71; b71; echo ""
declare -a Default_DT_SR_choice=( "YES" "NO" )
for var in "${!Default_DT_SR_choice[@]}" ; do echo "			$((var+1)) : ${Default_DT_SR_choice[$var]}" | tee -a "$CRT_LOG"; done
echo ""; b71; echo "##     Do you want to enter the advanced configuration menu?         ##" | tee -a "$CRT_LOG"; e71
echo "##  Recommended only for experienced users or troubleshooting cases. ##"
echo "##       If unsure, it’s best to skip this step and press ENTER.     ##"; b71; pick choice_DT_SR $((var+1)) b
DT_SR_Choice="NO"
if [[ -z "$choice_DT_SR" || $choice_DT_SR = "2" ]] ; then
	echo "                    your choice is : Skipping advanced configuration (using defaults)." | tee -a "$CRT_LOG"
else
	DT_SR_Choice=${Default_DT_SR_choice[$choice_DT_SR-1]}
echo -e "                    your choice is :${GREEN} $DT_SR_Choice ${NOCOLOR}" | tee -a "$CRT_LOG"
fi
if [ "$DT_SR_Choice" == "YES" ] ; then
	echo -n -e "                       PRESS ${BLUE}ENTER${NOCOLOR} TO CONTINUE "; read; echo; echo ""; b71; e71
	echo "##                      ADVANCED CONFIGURATION       1/3             ##" | tee -a "$CRT_LOG"; e71
	echo "##                   Minimum Dotclock Configuration                  ##"; e71
	echo "##  This setting defines the lowest pixel clock (MHz) your GPU can   ##"
	echo "##  use when generating video modes. In most cases, this value can   ##"
	echo "##  safely remain at 0 MHz.                                          ##"; e71
	echo "##  ⚠️  For AMD GPUs (and most Nvidia Maxwell cards), setting a       ##"
	echo "##  minimum dotclock manually is almost never required.              ##"
	echo "##  The hardware already supports a low dotclock of 0 MHz by design. ##"; e71
	echo "##  Only adjust this if you are experiencing launch issues in        ##"
	echo "##  certain emulators or cores (e.g., NES, PC Engine) that display   ##"
	echo "##  a black screen due to unsupported timing.                        ##"; e71
	echo "##  If you are unsure, leave this unchanged and just press ENTER.    ##"; e71; b71; echo ""
	declare -a dcm_selector=( "Low - 0" "Mild - 6" "Medium - 12" "High - 25" "CUSTOM")
	for var in "${!dcm_selector[@]}" ; do echo "			$((var+1)) : ${dcm_selector[$var]}" | tee -a "$CRT_LOG"; done
	echo ""; b71; echo "##                Choose a minimum dotclock threshold                ##"
	echo "##      This defines the lowest pixel clock allowed for modes.       ##"
	echo "##           Press ENTER to keep the default value of 0 MHz.         ##"; b71; pick dcm $((var+1)) b
	if [ -z "$dcm" ] ; then
		echo -e "                    your choice is :${GREEN} Batocera default minimum dotclock${NOCOLOR}" | tee -a "$CRT_LOG"
	else
		echo -e "                    your choice is :${GREEN}  ${dcm_selector[$dcm-1]}${NOCOLOR}" | tee -a "$CRT_LOG"
		case $dcm in
			1) dotclock_min=0;;
			2) dotclock_min=6;;
			3) dotclock_min=12;;
			4) dotclock_min=25;;
			5) echo "#######################################################################"
				e71; echo "##         Enter your custom minimum dotclock value (0–25 MHz)       ##"
				echo "##       Only change this if you know your hardware’s limits.        ##"
				echo "##  (Used to restrict the lowest pixel clock allowed by modelines)   ##"
				echo "##         If unsure, use the default value (0 MHz).                 ##"; e71; b71
				num dotclock_min 25 "Enter number between 0 and 25 for dotclock_min: "
				echo -e "                    CUSTOM dotclock_min value = ${GREEN}${dotclock_min}${NOCOLOR}" | tee -a "$CRT_LOG" ;;
		esac
	fi
monitor_MAME_CHOICE=${monitor_MAME_CHOICE:-NO}
	if [ "$monitor_MAME_CHOICE" = "YES" ] ; then
		echo ""; b71; e71; echo "##                      ADVANCED CONFIGURATION       1b/3            ##" | tee -a "$CRT_LOG"
		e71; echo "##                           MAME MONITOR                            ##"; e71
		echo "##  This section adjusts the minimum dotclock used by MAME only.     ##"
		echo "##  In most setups you should leave this unchanged.                   ##"
		echo "##  Change it only if some games/cores launch to a black screen.     ##"; e71
		echo "##              ==  MAME minimum dotclock selector  ==               ##"; e71
		echo "##  Press ENTER to keep the same dotclock_min as the main monitor.   ##"
		echo "##  If you know what you are doing, select a different value below.  ##"; e71; b71
 		echo ""
		declare -a dcm_m_selector=( "Low - 0" "Mild - 6" "Medium - 12" "High - 25" "CUSTOM")
		for var in "${!dcm_m_selector[@]}" ; do echo "			$((var+1)) : ${dcm_m_selector[$var]}" | tee -a "$CRT_LOG"; done
		echo ""; b71; echo "##           Select your preferred MAME minimum dotclock value       ##"
		echo "##        (Press ENTER to keep the same as your main monitor)        ##"; b71; pick dcm_m $((var+1)) b
		if [ -z "$dcm_m" ] ; then
			echo -e "                    your choice is :${GREEN} Same as main monitor ($dotclock_min)${NOCOLOR}" | tee -a "$CRT_LOG"
			dotclock_min_mame=$dotclock_min
		else
			echo -e "                    your choice is :${GREEN}  ${dcm_m_selector[$dcm_m-1]}${NOCOLOR}" | tee -a "$CRT_LOG"
			case $dcm_m in
				1) dotclock_min_mame=0;;
				2) dotclock_min_mame=6;;
				3) dotclock_min_mame=12;;
				4) dotclock_min_mame=25;;
				5) echo "#######################################################################"
					echo "##     Enter your custom MAME minimum dotclock value (0–25 MHz)      ##" | tee -a "$CRT_LOG"
					echo "##     Only change this if you understand your hardware limits.      ##" | tee -a "$CRT_LOG"; b71
					num dotclock_min_mame 25 "Enter number between 0 and 25 for dotclock_min_mame: "
					echo -e "                    CUSTOM dotclock_min_mame value = ${GREEN}${dotclock_min_mame}${NOCOLOR}" | tee -a "$CRT_LOG" ;;
			esac
		fi
	fi
	echo ""; b71; e71; echo "##                      ADVANCED CONFIGURATION       2/3             ##" | tee -a "$CRT_LOG"
	e71; echo "##                     ==  Super-Resolution  ==                      ##"; e71
	echo "##      This option defines the virtual width used by Switchres.     ##"
	echo "##     It helps reduce video mode changes between different games.   ##"; e71
	echo "##     You can select a default value recommended for your GPU, or   ##"
	echo "##        specify a custom one (advanced users only).                ##"; e71
	echo "##     If you are unsure, simply press ENTER to use the default.     ##"; e71; b71; echo ""
	declare -a sr_selector=( "1920 - Intel default" "2560 - amd/ati default" "3840 - nvidia default" "CUSTOM (experimental)")
	for var in "${!sr_selector[@]}" ; do echo "			$((var+1)) : ${sr_selector[$var]}" | tee -a "$CRT_LOG"; done
	echo ""; b71; echo "##               Select your preferred super-resolution              ##"
	echo "##          (Press ENTER to skip this configuration step)            ##"; b71; pick sr_choice $((var+1)) b
	if [ -z "$sr_choice" ] ; then
		echo -e "                    your choice is :${GREEN} default super-resolution${NOCOLOR}" | tee -a "$CRT_LOG"
	else
		echo -e "                    your choice is :${GREEN}  ${sr_selector[$sr_choice-1]}${NOCOLOR}" | tee -a "$CRT_LOG"
		case $sr_choice in
			1) super_width=1920;;
			2) super_width=2560;;
			3) super_width=3840;;
			4) echo "#######################################################################"
				echo "##           Enter a valid number between 0 and 25 MHz               ##"
				echo "##       for your custom super-resolution minimum dotclock.          ##"; b71
				num super_width "" "Enter valid number greater than 0 for custom super-resolution:"
				echo -e "                    CUSTOM super-resolution value = ${GREEN}${super_width}${NOCOLOR}" | tee -a "$CRT_LOG" ;;
		esac
	fi
monitor_MAME_CHOICE=${monitor_MAME_CHOICE:-NO}
	if [ "$monitor_MAME_CHOICE" = "YES" ] ; then
		echo ""; b71; e71; echo "##                      ADVANCED CONFIGURATION       2b/3            ##" | tee -a "$CRT_LOG"
		e71; echo "##                    ==     MAME Super-Resolution     ==             ##"; e71
		echo "##     This option defines the vertical super-resolution used by      ##"
		echo "##     MAME when generating dynamic modelines for arcade games.       ##"
		echo "##     You can choose a recommended preset or define your own         ##"
		echo "##     custom value for testing and fine-tuning purposes.             ##"; e71
		echo "##     In most cases, the default value for your GPU is optimal.      ##"
		echo "##     If you are unsure what this means, simply press ENTER to       ##"
		echo "##     keep the default setting.                                      ##"; e71; b71; echo ""
		declare -a sr_m_selector=( "1920 - Intel default" "2560 - amd/ati/ default" "3840 - nvidia default" "Same as main monitor" "CUSTOM (experimental)")
		for var in "${!sr_m_selector[@]}" ; do echo "			$((var+1)) : ${sr_m_selector[$var]}" | tee -a "$CRT_LOG"; done
		echo ""; b71; echo "##     Choose a MAME super-resolution preset, or CUSTOM (width)      ##"
		echo "##           Press ENTER to keep the default for your GPU            ##"; b71; pick sr_m_choice $((var+1)) b
		if [ -z "$sr_m_choice" ] ; then
			echo -e "                    your choice is :${GREEN} MAME default super-resolution${NOCOLOR}" | tee -a "$CRT_LOG"
		else
			echo -e "                    your choice is :${GREEN}  ${sr_m_selector[$sr_m_choice-1]}${NOCOLOR}" | tee -a "$CRT_LOG"
			case $sr_m_choice in
				1) super_width_mame=1920;;
				2) super_width_mame=2560;;
				3) super_width_mame=3840;;
				4) super_width_mame=$super_width;;
				5) echo "#######################################################################"
					echo "##             Select your custom MAME super_resolution              ##"; b71
					num super_width_mame "" "Enter valid number greater than 0 for custom super-resolution"
					echo -e "                    CUSTOM MAME super-resolution value = ${GREEN}${super_width_mame}${NOCOLOR}" | tee -a "$CRT_LOG" ;;
			esac
		fi
	fi
fi
echo ""; b71; e71; echo "##                      ADVANCED CONFIGURATION       3/3             ##" | tee -a "$CRT_LOG"
e71; echo "##                         USB FAST POLLING                          ##"; e71
echo "##  Adjust the USB polling rate for controllers/encoders to reduce   ##"
echo "##  input latency. Higher rates can improve responsiveness but may   ##"
echo "##  increase CPU usage or cause issues on some devices.              ##"; e71
echo "##  If you are unsure, leave this unchanged. Batocera’s default is   ##"
echo "##  generally optimal. Press ENTER to keep the default setting.      ##"; e71; b71; echo ""
declare -a usb_selector=( "Activate(reduce input lag)" "Keep default" )
for var in "${!usb_selector[@]}" ; do echo "			$((var+1)) : ${usb_selector[$var]}" | tee -a "$CRT_LOG"; done
echo ""; b71; echo "##                 Select your USB polling rate option               ##"
echo "##           (Press ENTER to keep the default configuration)         ##"; b71; pick p_rate $((var+1)) b
if [ -z "$p_rate" ] ; then
	echo -e "                    your choice is :${GREEN} Batocera default usb polling rate${NOCOLOR}" | tee -a "$CRT_LOG"
	polling_rate="usbhid.jspoll=0 xpad.cpoll=0"
elif [ "x$p_rate" != "x0" ] ; then
	echo -e "                    your choice is :${GREEN}  ${usb_selector[$p_rate-1]}${NOCOLOR}" | tee -a "$CRT_LOG"
	case $p_rate in
		1) polling_rate="usbhid.jspoll=1 xpad.cpoll=1";;
		*) polling_rate="usbhid.jspoll=0 xpad.cpoll=0";;
	esac
fi
