
#############################################################################
##            Single 20-modesetting.conf for AMD (v42-safe) START          ##
#############################################################################

# First time using the script backup the 20-amdgpu.conf & 20-radeon.conf
if [ ! -f "/etc/X11/xorg.conf.d/20-amdgpu.conf.bak" ];then
	cp /etc/X11/xorg.conf.d/20-amdgpu.conf /etc/X11/xorg.conf.d/20-amdgpu.conf.bak
fi

if [ ! -f "/etc/X11/xorg.conf.d/20-radeon.conf.bak" ];then
	cp /etc/X11/xorg.conf.d/20-radeon.conf /etc/X11/xorg.conf.d/20-radeon.conf.bak
fi 

# Now delete the files so they are no longer loaded during boot
for f in /etc/X11/xorg.conf.d/20-radeon.conf /etc/X11/xorg.conf.d/20-amdgpu.conf; do
  [ -e "$f" ] && rm -f "$f"
done
 
# Copy over the new 20-modesetting.conf & set correct file permission
cp /userdata/system/Batocera-CRT-Script/etc_configs/Monitors_config/20-modesetting.conf /etc/X11/xorg.conf.d/20-modesetting.conf
chmod 644 /etc/X11/xorg.conf.d/20-modesetting.conf

#############################################################################
##            Single 20-modesetting.conf for AMD (v42-safe) END            ##
#############################################################################

##################################################################################################
python_directory=$(find /usr/lib/ -maxdepth 1 -type d -name "python*" -exec basename {} \; -quit)
new_path="/usr/lib/${python_directory}/site-packages/batocera_launch/devices/"
if [ ! -f "${new_path}video.py.bak" ];then
	cp "${new_path}video.py" 		"${new_path}video.py.bak"
fi
##################################################################################################



## Only for Batocera >= V32
case $Version_of_batocera in

    v44)		
		cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/Configgen/Video.py-v44_ZFEbHVUE		"${new_path}video.py"
		chmod 755 "${new_path}video.py"

		if [ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]; then
			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/batocera-resolution-v44_Nvidia_driver_MYZAR_ZFEbHVUE-MultiScreen 	/usr/bin/batocera-resolution
		else
			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/batocera-resolution-v44_MYZAR_ZFEbHVUE-MultiScreen	/usr/bin/batocera-resolution

		fi
		
		cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/emulationstation-standalone-v44_ZFEbHVUE-MultiScreen	/usr/bin/emulationstation-standalone

		chmod 755 /usr/bin/batocera-resolution 
		chmod 755 /usr/bin/emulationstation-standalone
		sed -e "s/\[monitor-name\]/$monitor_name_MAME/g" -e "s/\[super_width\]/$super_width/g" -e "s/\[dotclock_min_value\]/$dotclock_min/g"  /userdata/system/Batocera-CRT-Script/etc_configs/switchres.ini-generic-v36 > /etc/switchres.ini
		sed -i "s/.*interlace_force_even   .*/        interlace_force_even      $IFE/" /etc/switchres.ini
 		chmod 755 /etc/switchres.ini

		cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/get_monitorRange  /usr/bin/get_monitorRange
		chmod 755 /usr/bin/get_monitorRange

		# v43 only: Add PSXC2 standalone aspect ratio 10:7 (1.43:1 — custom).
		# Remove when v44 ships IF this is added upstream.
		#cp /usr/share/emulationstation/es_features.cfg /usr/share/emulationstation/es_features.cfg.bak && sed -i '/<choice name="Widescreen (16:9)" value="16:9" \/>/a\          <choice name="10:7 (1.43:1 — custom)" value="10:7" />' /usr/share/emulationstation/es_features.cfg

	;;



	*)
		echo "PROBLEM OF VERSION"
		exit 1;
	;;
esac

cp /etc/switchres.ini /etc/switchres.ini.bak

#stop ES
if [ ! -f "/usr/bin/stop" ];then
	touch /usr/bin/stop
	echo "#!/bin/bash" 				>> /usr/bin/stop
	echo  "/etc/init.d/S31emulationstation stop" 	>> /usr/bin/stop
	chmod 755 /usr/bin/stop
fi
#start ES
if [ ! -f "/usr/bin/start" ];then
	touch /usr/bin/start
	echo "#!/bin/bash" 				>> /usr/bin/start
	echo  "/etc/init.d/S31emulationstation start" 	>> /usr/bin/start
	chmod 755 /usr/bin/start
fi


#######################################################################################
## Remove Beta name from splash screen if using a beta.
#######################################################################################
if [ -f "/usr/share/batocera/splash/splash.srt" ];then
	mv /usr/share/batocera/splash/splash.srt /usr/share/batocera/splash/splash.srt.bak
fi
#######################################################################################
## make splash screen rotation if using tate mode (right or left).
#######################################################################################
if [ ! -f "/usr/share/batocera/splash/boot-logo.png.bak" ]; then
	cp /usr/share/batocera/splash/boot-logo.png /usr/share/batocera/splash/boot-logo.png.bak
fi
cp /userdata/system/Batocera-CRT-Script/Boot_logos/boot-logo.png /usr/share/batocera/splash/boot-logo.png 
if [ "$display_rotate" == "right" ];then

	cp /userdata/system/Batocera-CRT-Script/Boot_logos/boot-logo_90.png /usr/share/batocera/splash/boot-logo.png 
fi
if [ "$display_rotate" == "inverted" ];then

	cp /userdata/system/Batocera-CRT-Script/Boot_logos/boot-logo_180.png /usr/share/batocera/splash/boot-logo.png 
fi
if  [ "$display_rotate" == "left" ]; then
	cp /userdata/system/Batocera-CRT-Script/Boot_logos/boot-logo_270.png /usr/share/batocera/splash/boot-logo.png  
fi
