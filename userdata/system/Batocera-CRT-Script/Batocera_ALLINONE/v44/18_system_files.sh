# Batocera-CRT-Script v44 - step 18: system files
# Xorg config, batocera_launch video.py, batocera-resolution, emulationstation-standalone,
# switchres.ini, /usr/bin/start and stop, boot logo.
if [ ! -f "/etc/X11/xorg.conf.d/20-amdgpu.conf.bak" ];then cp /etc/X11/xorg.conf.d/20-amdgpu.conf /etc/X11/xorg.conf.d/20-amdgpu.conf.bak; fi
if [ ! -f "/etc/X11/xorg.conf.d/20-radeon.conf.bak" ];then cp /etc/X11/xorg.conf.d/20-radeon.conf /etc/X11/xorg.conf.d/20-radeon.conf.bak; fi
for f in /etc/X11/xorg.conf.d/20-radeon.conf /etc/X11/xorg.conf.d/20-amdgpu.conf; do [ -e "$f" ] && rm -f "$f"; done
cp "$CRTD"/etc_configs/Monitors_config/20-modesetting.conf /etc/X11/xorg.conf.d/20-modesetting.conf
chmod 644 /etc/X11/xorg.conf.d/20-modesetting.conf
python_directory=$(find /usr/lib/ -maxdepth 1 -type d -name "python*" -exec basename {} \; -quit)
new_path="/usr/lib/${python_directory}/site-packages/batocera_launch/devices/"
if [ ! -f "${new_path}video.py.bak" ];then cp "${new_path}video.py" "${new_path}video.py.bak"; fi
case $Version_of_batocera in
    v44)
		cp "$CRTD"/UsrBin_configs/Configgen/Video.py-v44_ZFEbHVUE "${new_path}video.py"; chmod 755 "${new_path}video.py"
		if [ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]; then
			cp "$CRTD"/UsrBin_configs/batocera-resolution-v44_Nvidia_driver_MYZAR_ZFEbHVUE-MultiScreen /usr/bin/batocera-resolution
		else cp "$CRTD"/UsrBin_configs/batocera-resolution-v44_MYZAR_ZFEbHVUE-MultiScreen /usr/bin/batocera-resolution; fi
		cp "$CRTD"/UsrBin_configs/emulationstation-standalone-v44_ZFEbHVUE-MultiScreen /usr/bin/emulationstation-standalone
		chmod 755 /usr/bin/batocera-resolution; chmod 755 /usr/bin/emulationstation-standalone
		if [ "${CRT_KEEP_GEOMETRY:-0}" = 1 ] && [ -s "${CRT_GEOMETRY_SNAPSHOT:-}" ]; then
			cp -a "$CRT_GEOMETRY_SNAPSHOT" /etc/switchres.ini
			sed -i "s/^[[:space:]]*dotclock_min[[:space:]].*/    dotclock_min              $dotclock_min/" /etc/switchres.ini
			sed -i "s/^[[:space:]]*super_width[[:space:]].*/	super_width               $super_width/" /etc/switchres.ini
			sed -i "s/^[[:space:]]*interlace_force_even[[:space:]].*/        interlace_force_even      $IFE/" /etc/switchres.ini
			echo "Kept custom geometry. Wrote dotclock ${dotclock_min} and super-res ${super_width}." >> "$CRT_LOG"
		else
			sed -e "s/\[monitor-name\]/$monitor_name_MAME/g" -e "s/\[super_width\]/$super_width/g" -e "s/\[dotclock_min_value\]/$dotclock_min/g" "$CRTD"/etc_configs/switchres.ini-generic-v36 > /etc/switchres.ini
			sed -i "s/.*interlace_force_even   .*/        interlace_force_even      $IFE/" /etc/switchres.ini
		fi
 		chmod 755 /etc/switchres.ini
		cp "$CRTD"/UsrBin_configs/get_monitorRange /usr/bin/get_monitorRange
		chmod 755 /usr/bin/get_monitorRange ;;
	*)
		echo "PROBLEM OF VERSION"
		exit 1; ;;
esac
cp /etc/switchres.ini /etc/switchres.ini.bak
for s in stop start; do
	if [ ! -f "/usr/bin/$s" ];then printf '#!/bin/bash\n/etc/init.d/S31emulationstation %s\n' "$s" > "/usr/bin/$s"; chmod 755 "/usr/bin/$s"; fi
done
if [ -f "/usr/share/batocera/splash/splash.srt" ];then mv /usr/share/batocera/splash/splash.srt /usr/share/batocera/splash/splash.srt.bak; fi
if [ ! -f "/usr/share/batocera/splash/boot-logo.png.bak" ]; then
	cp /usr/share/batocera/splash/boot-logo.png /usr/share/batocera/splash/boot-logo.png.bak
fi
cp "$CRTD"/Boot_logos/boot-logo.png /usr/share/batocera/splash/boot-logo.png
if [ "$display_rotate" == "right" ];then cp "$CRTD"/Boot_logos/boot-logo_90.png /usr/share/batocera/splash/boot-logo.png; fi
if [ "$display_rotate" == "inverted" ];then cp "$CRTD"/Boot_logos/boot-logo_180.png /usr/share/batocera/splash/boot-logo.png; fi
if [ "$display_rotate" == "left" ]; then cp "$CRTD"/Boot_logos/boot-logo_270.png /usr/share/batocera/splash/boot-logo.png; fi
