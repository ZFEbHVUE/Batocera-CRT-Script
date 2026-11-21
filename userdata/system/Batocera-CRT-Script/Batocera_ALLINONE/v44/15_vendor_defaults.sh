# Batocera-CRT-Script v44 - step 15: vendor defaults
# Per-vendor defaults: dotclock_min, super_width (and their MAME copies), drivers_amd, video_modeline.
super_width_vertical=1920; interlace_vertical=0
dotclock_min_vertical=25
super_width_horizont=1920; interlace_horizont=0
dotclock_min_horizont=25
# Known gaps kept from the original script: INTEL has no HDMI branch and nouveau on DP never sets
# dotclock_min_mame, so with set -u those two setups stop later in the install.
case $TYPE_OF_CARD in
AMD/ATI)
	dotclock_min=0; dotclock_min_mame=$dotclock_min; super_width=2560; super_width_mame=2560; drivers_type=AMDGPU
	if [ "$R9_380" == "YES" ]; then drivers_amd="amdgpu.dc=0"; else drivers_amd=""; fi
	echo "AMDGPU" >> "$TCD"
	case $video_output in
	*DP*|*DVI*|*VGA*) video_modeline=$video_output_xrandr ;;
	*HDMI*) video_modeline=$video_output_xrandr; dotclock_min=25.0; dotclock_min_mame=$dotclock_min; super_width=3840; super_width_mame=$super_width ;;
	esac ;;
INTEL)
	drivers_amd=""
	case $video_output in
	*DP*) video_modeline=$video_output_xrandr; dotclock_min=0; dotclock_min_mame=$dotclock_min; super_width=1920; super_width_mame=$super_width ;;
	*VGA*) video_modeline=$video_output_xrandr; dotclock_min=25.0; dotclock_min_mame=$dotclock_min; super_width=1920; super_width_mame=$super_width ;;
	esac ;;
NVIDIA)
	drivers_amd=""
	case $video_output in
	*DP*) dotclock_min=0; [ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ] && dotclock_min_mame=$dotclock_min ;;
	*DVI*) if [ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ] && [ "$Drivers_Name_Nvidia_CHOICE" != "legacy470" ]; then dotclock_min=0; else dotclock_min=25; fi
		dotclock_min_mame=$dotclock_min ;;
	*HDMI*) dotclock_min=25.0; dotclock_min_mame=$dotclock_min ;;
	*VGA*) if [ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]; then dotclock_min=25.0; else dotclock_min=0.0; fi
		dotclock_min_mame=$dotclock_min ;;
	esac
	case $video_output in *DP*|*DVI*|*HDMI*|*VGA*) video_modeline=$video_output_xrandr; super_width=3840; super_width_mame=$super_width ;; esac ;;
esac
if [ "$CRT_Freq" == "31KHz" ]; then
	dotclock_min=25.0
	dotclock_min_mame=$dotclock_min
fi
echo -n -e "                       PRESS ${BLUE}ENTER${NOCOLOR} TO CONTINUE "; read; echo
