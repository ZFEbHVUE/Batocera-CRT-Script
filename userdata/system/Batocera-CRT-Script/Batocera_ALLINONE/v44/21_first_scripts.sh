
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
		-e "s/\[card_display\]/$video_modeline/g" -e "s/\[es_resolution\]/$RES_EDID/g" /userdata/system/Batocera-CRT-Script/System_configs/First_script/first_script.sh-generic-v42 > /userdata/system/scripts/first_script.sh
else
	sed 	-e "s/\[display_mame_rotation\]/$display_mame_rotate/g" -e "s/\[display_fbneo_rotation\]/$display_fbneo_rotate/g" -e "s/\[display_libretro_rotation\]/$display_libretro_rotate/g" \
		-e "s/\[display_standalone_rotation\]/$display_standalone_rotate/g" -e "s/\[display_ES_rotation\]/$display_rotate/g" \
		-e "s/\[card_display\]/$video_modeline/g" -e "s/\[es_resolution\]/$RES_EDID_SCANNING/g" /userdata/system/Batocera-CRT-Script/System_configs/First_script/first_script.sh-generic-v42 > /userdata/system/scripts/first_script.sh
fi
chmod 755 /userdata/system/scripts/first_script.sh
######################################################################################
# Create 1_GunCon2.sh and GunCon2_Calibration.sh
######################################################################################
sed -e "s/\[card_display\]/$video_modeline/g" /userdata/system/Batocera-CRT-Script/System_configs/First_script/1_GunCon2.sh-generic > /userdata/system/scripts/1_GunCon2.sh
chmod 755 /userdata/system/scripts/1_GunCon2.sh
sed -e "s/\[card_display\]/$video_modeline/g" /userdata/system/Batocera-CRT-Script/GunCon2/GunCon2_Calibration.sh-generic > "$CRT_ROMS/crt/GunCon2_Calibration.sh"
chmod 755 "$CRT_ROMS/crt/GunCon2_Calibration.sh"


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
