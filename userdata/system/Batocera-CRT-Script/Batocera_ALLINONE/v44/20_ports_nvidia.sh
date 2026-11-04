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


