# Batocera-CRT-Script v44 - step 20: crt tools
# CRT tools in ES (geometry, grid, mode switcher), GunCon2 plugin/shader/udev, VNC, overlays,
# media keys, Kodi; then the overlay is saved.
if [ -d "/userdata/.roms_base" ]; then
  CRT_ROMS="/userdata/.roms_base"
else CRT_ROMS="/userdata/roms"; fi
cp -a "$CRTD"/Geometry_modeline/crt/ "$CRT_ROMS/"
cp "$CRTD"/Geometry_modeline/es_systems_crt.cfg /userdata/system/configs/emulationstation/es_systems_crt.cfg
chmod 755 "$CRTD"/Geometry_modeline/crt-launcher.sh
cp "$CRTD"/Geometry_modeline/CRT.png /usr/share/emulationstation/themes/es-theme-carbon/art/consoles/CRT.png
cp "$CRTD"/Geometry_modeline/CRT.svg /usr/share/emulationstation/themes/es-theme-carbon/art/logos/CRT.svg
chmod 755 "$CRT_ROMS"/crt/{es_adjust_tool.sh,geometry.sh,grid_tool.sh} "$CRTD"/Geometry_modeline/{es_tool.sh,es_tool_legacy.sh,geometry.sh,grid_tool.sh}
chmod 0644 "$CRTD"/Geometry_modeline/es_tool.py "$CRT_ROMS"/crt/{es_adjust_tool.sh.keys,geometry.sh.keys,grid_tool.sh.keys}
if [ -f "${CRTD}/Geometry_modeline/crt/mode_switcher.sh" ]; then
    if [ -f "${CRTD}/Geometry_modeline/mode_switcher.sh" ]; then chmod 755 "$CRTD"/Geometry_modeline/mode_switcher.sh; fi
    cp "$CRTD"/Geometry_modeline/crt/mode_switcher.sh "$CRT_ROMS/crt/mode_switcher.sh"
    chmod 755 "$CRT_ROMS/crt/mode_switcher.sh"
    if [ -f "${CRTD}/Geometry_modeline/crt/mode_switcher.sh.keys" ]; then
        cp "$CRTD"/Geometry_modeline/crt/mode_switcher.sh.keys "$CRT_ROMS/crt/mode_switcher.sh.keys"
        chmod 644 "$CRT_ROMS/crt/mode_switcher.sh.keys"
    fi
    if [ -f "${CRTD}/Geometry_modeline/crt/gamelist.xml" ]; then
        cp "$CRTD"/Geometry_modeline/crt/gamelist.xml "$CRT_ROMS/crt/gamelist.xml"
        chmod 644 "$CRT_ROMS/crt/gamelist.xml"
    fi
    mkdir -p /userdata/Batocera-CRT-Script-Backup/mode_backups/{hd_mode,crt_mode}/{boot_configs,emulator_configs,video_settings}
    echo "Mode Switcher installed successfully."
else echo "Mode Switcher script not found. Skipping installation."; fi
if [ ! -d "/usr/bin/mame/plugins/gunlight" ];then mkdir /usr/bin/mame/plugins/gunlight; fi
if ([ "$Version_of_batocera" == "v44" ]); then
	for f in gunlight_menu.lua gunlight_save.lua init-v44.lua plugin.json; do cp "$CRTD/GunCon2/gunlight/$f" "/usr/bin/mame/plugins/gunlight/${f/-v44/}"; done
	chmod 644 /usr/bin/mame/plugins/gunlight/{gunlight_menu.lua,gunlight_save.lua,init.lua,plugin.json}
fi
if [ ! -d "/usr/share/batocera/shaders/configs/lightgun-shader" ];then mkdir /usr/share/batocera/shaders/configs/lightgun-shader; fi
	cp "$CRTD"/GunCon2/shader/lightgun-shader/rendering-defaults.yml /usr/share/batocera/shaders/configs/lightgun-shader/rendering-defaults.yml
	chmod 644 /usr/share/batocera/shaders/configs/lightgun-shader/rendering-defaults.yml
	cp "$CRTD"/GunCon2/shader/misc/image-adjustment_lgun.slangp /usr/share/batocera/shaders/misc/image-adjustment_lgun.slangp
	cp "$CRTD"/GunCon2/shader/misc/shaders/image-adjustment_lgun.slang /usr/share/batocera/shaders/misc/shaders/image-adjustment_lgun.slang
	chmod 644 /usr/share/batocera/shaders/misc/image-adjustment_lgun.slangp
	chmod 644 /usr/share/batocera/shaders/misc/shaders/image-adjustment_lgun.slang
	if [ ! -f "/etc/udev/rules.d/99-guncon.rules.bak" ];then cp /etc/udev/rules.d/99-guncon.rules /etc/udev/rules.d/99-guncon.rules.bak; fi
	cp "$CRTD"/GunCon2/99-guncon.rules-generic /etc/udev/rules.d/99-guncon.rules
        if [ ! -f "/usr/bin/guncon2_calibrate.sh.bak" ];then cp /usr/bin/guncon2_calibrate.sh /usr/bin/guncon2_calibrate.sh.bak; fi
	sed -e "s/\[guncon2_x\]/$Guncon2_x/g" -e "s/\[guncon2_y\]/$Guncon2_y/g" -e "s/\[guncon2_f\]/$Guncon2_freq/g" -e "s/\[guncon2_res\]/$Guncon2_res/g" \
		"$CRTD"/GunCon2/guncon2_calibrate.sh-generic > /usr/bin/guncon2_calibrate.sh
        chmod 755 /usr/bin/guncon2_calibrate.sh
	if [ ! -f "/usr/bin/calibrate.py.bak" ];then cp /usr/bin/calibrate.py /usr/bin/calibrate.py.bak; fi
	if [ "$ES_rotation" == "NORMAL" ] || [ "$ES_rotation" == "INVERTED" ]; then
		sed -e "s/\[guncon2_x\]/$Guncon2_x/g" -e "s/\[guncon2_y\]/$Guncon2_y/g" -e "s/\[guncon2_res\]/$Guncon2_res/g" \
		       	"$CRTD"/GunCon2/calibrate.py-generic > /usr/bin/calibrate.py
	else
		sed -e "s/\[guncon2_y\]/$Guncon2_x/g" -e "s/\[guncon2_x\]/$Guncon2_y/g" -e "s/\[guncon2_res\]/$Guncon2_res/g" \
		       	"$CRTD"/GunCon2/calibrate.py-generic > /usr/bin/calibrate.py
	fi
	chmod 755 /usr/bin/calibrate.py
V="$CRTD"/install-vnc_server_batocera; cp "$V"/libcrypt.so.1 /lib/libcrypt.so.1
cp "$V"/{libcrypt.so.1,libvncclient.so.1,libvncserver.so.1,libsasl2.so.2} /usr/lib/
cp "$V"/{vnc,x11vnc,vnc-scaled} /usr/bin/; chmod 0755 /lib/libcrypt.so.1
chmod 0644 /usr/lib/{libcrypt.so.1,libvncclient.so.1,libvncserver.so.1,libsasl2.so.2}
chmod +x /usr/bin/{vnc,x11vnc,vnc-scaled}; cp "$CRTD"/extra/overlays_overrides.sh "$CRT_ROMS/crt"
cp "$CRTD"/extra/overlays_overrides.sh.keys "$CRT_ROMS/crt"; chmod 755 "$CRT_ROMS/crt/overlays_overrides.sh"
chmod 644 "$CRT_ROMS/crt/overlays_overrides.sh.keys"; chmod 755 "$CRTD"/extra/overlays_overrides_script.sh
cp "$CRTD"/extra/media_keys/multimedia_keys.conf /userdata/system/configs/
cp "$CRTD"/extra/media_keys/{esrestart,xrestart,emukill} /usr/bin
cp "$CRTD"/extra/media_keys/crt-mode-switch-combo /tmp/crt-mode-switch-combo.install
chmod 755 /tmp/crt-mode-switch-combo.install; rm -rf /usr/bin/crt-mode-switch-combo
mv /tmp/crt-mode-switch-combo.install /usr/bin/crt-mode-switch-combo; chmod 755 /usr/bin/crt-mode-switch-combo
cp "$CRTD"/extra/media_keys/crt-mode-switch-watcher.py /usr/bin; chmod 644 /userdata/system/configs/multimedia_keys.conf
chmod 755 /usr/bin/{esrestart,xrestart,emukill,crt-mode-switch-combo,crt-mode-switch-watcher.py}
UD_MEDIA_KEYS="${CRTD}/extra/media_keys"; mkdir -p "$UD_MEDIA_KEYS"
cp -f /usr/bin/crt-mode-switch-combo "$UD_MEDIA_KEYS/crt-mode-switch-combo"
cp -f /usr/bin/crt-mode-switch-watcher.py "$UD_MEDIA_KEYS/crt-mode-switch-watcher.py"
chmod 755 "$UD_MEDIA_KEYS/crt-mode-switch-combo" "$UD_MEDIA_KEYS/crt-mode-switch-watcher.py"
mkdir -p /userdata/system/services
cp "$CRTD"/extra/media_keys/crt_mode_switch_watcher /userdata/system/services/crt_mode_switch_watcher
chmod 755 /userdata/system/services/crt_mode_switch_watcher; cp "$CRTD"/extra/Kodi/Kodi.sh /userdata/roms/ports
chmod 755 /userdata/roms/ports/Kodi.sh; batocera-save-overlay
