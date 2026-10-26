#######################################################################################
# Create GunCon2 LUA plugin for GroovyMame for V36, V37 and V38
#######################################################################################
## if the folder doesn't exist, it will be created now
if [ ! -d "/usr/bin/mame/plugins/gunlight" ];then
	mkdir /usr/bin/mame/plugins/gunlight
fi
if ([ "$Version_of_batocera" == "v44" ]); then
	cp /userdata/system/Batocera-CRT-Script/GunCon2/gunlight/gunlight_menu.lua /usr/bin/mame/plugins/gunlight/gunlight_menu.lua
	cp /userdata/system/Batocera-CRT-Script/GunCon2/gunlight/gunlight_save.lua /usr/bin/mame/plugins/gunlight/gunlight_save.lua
#only for V44.
	cp /userdata/system/Batocera-CRT-Script/GunCon2/gunlight/init-v44.lua /usr/bin/mame/plugins/gunlight/init.lua
#	
	cp /userdata/system/Batocera-CRT-Script/GunCon2/gunlight/plugin.json /usr/bin/mame/plugins/gunlight/plugin.json
	chmod 644 /usr/bin/mame/plugins/gunlight/gunlight_menu.lua
	chmod 644 /usr/bin/mame/plugins/gunlight/gunlight_save.lua
	chmod 644 /usr/bin/mame/plugins/gunlight/init.lua
	chmod 644 /usr/bin/mame/plugins/gunlight/plugin.json
fi

#######################################################################################
# Create GunCon2 shader for V36, V37 and v38
#######################################################################################
## if the folder doesn't exist, it will be created now
if [ ! -d "/usr/share/batocera/shaders/configs/lightgun-shader" ];then
	mkdir /usr/share/batocera/shaders/configs/lightgun-shader
fi
	cp /userdata/system/Batocera-CRT-Script/GunCon2/shader/lightgun-shader/rendering-defaults.yml /usr/share/batocera/shaders/configs/lightgun-shader/rendering-defaults.yml
	chmod 644 /usr/share/batocera/shaders/configs/lightgun-shader/rendering-defaults.yml
	cp /userdata/system/Batocera-CRT-Script/GunCon2/shader/misc/image-adjustment_lgun.slangp /usr/share/batocera/shaders/misc/image-adjustment_lgun.slangp
	cp /userdata/system/Batocera-CRT-Script/GunCon2/shader/misc/shaders/image-adjustment_lgun.slang /usr/share/batocera/shaders/misc/shaders/image-adjustment_lgun.slang
	chmod 644 /usr/share/batocera/shaders/misc/image-adjustment_lgun.slangp
	chmod 644 /usr/share/batocera/shaders/misc/shaders/image-adjustment_lgun.slang

	if [ ! -f "/etc/udev/rules.d/99-guncon.rules.bak" ];then                                                           
		cp /etc/udev/rules.d/99-guncon.rules /etc/udev/rules.d/99-guncon.rules.bak                       
	fi
 
	cp /userdata/system/Batocera-CRT-Script/GunCon2/99-guncon.rules-generic /etc/udev/rules.d/99-guncon.rules

        if [ ! -f "/usr/bin/guncon2_calibrate.sh.bak" ];then                                                           
		cp /usr/bin/guncon2_calibrate.sh /usr/bin/guncon2_calibrate.sh.bak                      
	fi

	sed -e "s/\[guncon2_x\]/$Guncon2_x/g" -e "s/\[guncon2_y\]/$Guncon2_y/g" -e "s/\[guncon2_f\]/$Guncon2_freq/g" -e "s/\[guncon2_res\]/$Guncon2_res/g" \
		/userdata/system/Batocera-CRT-Script/GunCon2/guncon2_calibrate.sh-generic  > /usr/bin/guncon2_calibrate.sh
        chmod 755 /usr/bin/guncon2_calibrate.sh


	if [ ! -f "/usr/bin/calibrate.py.bak" ];then                                                           
		cp /usr/bin/calibrate.py /usr/bin/calibrate.py.bak                      
	fi
	if [ "$ES_rotation" == "NORMAL" ] || [ "$ES_rotation" == "INVERTED" ]; then	
		sed -e "s/\[guncon2_x\]/$Guncon2_x/g" -e "s/\[guncon2_y\]/$Guncon2_y/g"  -e "s/\[guncon2_res\]/$Guncon2_res/g" \
		       	/userdata/system/Batocera-CRT-Script/GunCon2/calibrate.py-generic   > /usr/bin/calibrate.py
	else
		sed -e "s/\[guncon2_y\]/$Guncon2_x/g" -e "s/\[guncon2_x\]/$Guncon2_y/g"  -e "s/\[guncon2_res\]/$Guncon2_res/g" \
		       	/userdata/system/Batocera-CRT-Script/GunCon2/calibrate.py-generic   > /usr/bin/calibrate.py
	fi
	chmod 755 /usr/bin/calibrate.py

