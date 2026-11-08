# Batocera-CRT-Script v44 - step 21: event scripts
# 99-nvidia.conf (proprietary driver) and event scripts (first_script.sh, 1_GunCon2.sh, GunCon2 calibration).
if [ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]; then
	if [ -f "/userdata/system/99-nvidia.conf" ]; then cp /userdata/system/99-nvidia.conf /userdata/system/99-nvidia.conf.bak; fi
	if [ "$CRT_Freq" == "15KHz" ]; then
		sed -e "s/.*Modeline.*/    Modeline            $MODELINE_CUSTOM/" -e "s/\[card_display\]/$video_modeline/g" "$CRTD"/System_configs/Nvidia/99-nvidia.conf-generic_15 > /userdata/system/99-nvidia.conf
	elif [ "$CRT_Freq" == "25KHz" ]; then
		sed -e "s/.*Modeline.*/    Modeline            $MODELINE_CUSTOM/" -e "s/\[card_display\]/$video_modeline/g" "$CRTD"/System_configs/Nvidia/99-nvidia.conf-generic_25 > /userdata/system/99-nvidia.conf
	else sed -e "s/\[card_display\]/$video_modeline/g" "$CRTD"/System_configs/Nvidia/99-nvidia.conf-generic_31 > /userdata/system/99-nvidia.conf; fi
	chmod 644 /userdata/system/99-nvidia.conf; cp /userdata/system/99-nvidia.conf /userdata/system/99-nvidia.conf.bak
else
	if [ -f "/userdata/system/99-nvidia.conf" ]; then
		cp /userdata/system/99-nvidia.conf /userdata/system/99-nvidia.conf.bak; rm /userdata/system/99-nvidia.conf
	fi
fi
if [ ! -d "/userdata/system/scripts" ];then mkdir /userdata/system/scripts; fi
if [ "$BOOT_RESOLUTION" == "1" ]; then
	sed -e "s/\[display_mame_rotation\]/$display_mame_rotate/g" -e "s/\[display_fbneo_rotation\]/$display_fbneo_rotate/g" -e "s/\[display_libretro_rotation\]/$display_libretro_rotate/g" \
		-e "s/\[display_standalone_rotation\]/$display_standalone_rotate/g" -e "s/\[display_ES_rotation\]/$display_rotate/g" \
		-e "s/\[card_display\]/$video_modeline/g" -e "s/\[es_resolution\]/$RES_EDID/g" "$CRTD"/System_configs/First_script/first_script.sh-generic-v42 > /userdata/system/scripts/first_script.sh
else
	sed -e "s/\[display_mame_rotation\]/$display_mame_rotate/g" -e "s/\[display_fbneo_rotation\]/$display_fbneo_rotate/g" -e "s/\[display_libretro_rotation\]/$display_libretro_rotate/g" \
		-e "s/\[display_standalone_rotation\]/$display_standalone_rotate/g" -e "s/\[display_ES_rotation\]/$display_rotate/g" \
		-e "s/\[card_display\]/$video_modeline/g" -e "s/\[es_resolution\]/$RES_EDID_SCANNING/g" "$CRTD"/System_configs/First_script/first_script.sh-generic-v42 > /userdata/system/scripts/first_script.sh
fi
chmod 755 /userdata/system/scripts/first_script.sh
sed -e "s/\[card_display\]/$video_modeline/g" "$CRTD"/System_configs/First_script/1_GunCon2.sh-generic > /userdata/system/scripts/1_GunCon2.sh
chmod 755 /userdata/system/scripts/1_GunCon2.sh
sed -e "s/\[card_display\]/$video_modeline/g" "$CRTD"/GunCon2/GunCon2_Calibration.sh-generic > "$CRT_ROMS/crt/GunCon2_Calibration.sh"
chmod 755 "$CRT_ROMS/crt/GunCon2_Calibration.sh"
