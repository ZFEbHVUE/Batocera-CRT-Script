# Batocera-CRT-Script v44 - step 20: mandatory CRT Tools
# Retains all required components and original destination paths. No overlay saving here.
if [[ -d /userdata/.roms_base ]]; then
  CRT_ROMS=/userdata/.roms_base
else
  CRT_ROMS=/userdata/roms
fi
write_run 20_crt_tools crt_launcher_install cp -a "$CRTD/Geometry_modeline/crt/" "$CRT_ROMS/"
write_run 20_crt_tools es_crt_registration cp "$CRTD/Geometry_modeline/es_systems_crt.cfg" /userdata/system/configs/emulationstation/es_systems_crt.cfg
write_run 20_crt_tools crt_launcher_permissions chmod 755 "$CRTD/Geometry_modeline/crt-launcher.sh"
write_run 20_crt_tools crt_png_install cp "$CRTD/Geometry_modeline/CRT.png" /usr/share/emulationstation/themes/es-theme-carbon/art/consoles/CRT.png
write_run 20_crt_tools crt_svg_install cp "$CRTD/Geometry_modeline/CRT.svg" /usr/share/emulationstation/themes/es-theme-carbon/art/logos/CRT.svg
write_run 20_crt_tools crt_scripts_permissions chmod 755 \
  "$CRT_ROMS/crt/es_adjust_tool.sh" "$CRT_ROMS/crt/geometry.sh" "$CRT_ROMS/crt/grid_tool.sh" \
  "$CRTD/Geometry_modeline/es_tool.sh" "$CRTD/Geometry_modeline/es_tool_legacy.sh" \
  "$CRTD/Geometry_modeline/geometry.sh" "$CRTD/Geometry_modeline/grid_tool.sh"
write_run 20_crt_tools crt_keys_permissions chmod 0644 \
  "$CRTD/Geometry_modeline/es_tool.py" \
  "$CRT_ROMS/crt/es_adjust_tool.sh.keys" "$CRT_ROMS/crt/geometry.sh.keys" "$CRT_ROMS/crt/grid_tool.sh.keys"
if [[ -f "$CRTD/Geometry_modeline/crt/mode_switcher.sh" ]]; then
  if [[ -f "$CRTD/Geometry_modeline/mode_switcher.sh" ]]; then
    write_run 20_crt_tools mode_switcher_source_permissions chmod 755 "$CRTD/Geometry_modeline/mode_switcher.sh"
  fi
  write_run 20_crt_tools mode_switcher_install cp "$CRTD/Geometry_modeline/crt/mode_switcher.sh" "$CRT_ROMS/crt/mode_switcher.sh"
  write_run 20_crt_tools mode_switcher_permissions chmod 755 "$CRT_ROMS/crt/mode_switcher.sh"
  if [[ -f "$CRTD/Geometry_modeline/crt/mode_switcher.sh.keys" ]]; then
    write_run 20_crt_tools mode_switcher_keys_install cp "$CRTD/Geometry_modeline/crt/mode_switcher.sh.keys" "$CRT_ROMS/crt/mode_switcher.sh.keys"
    write_run 20_crt_tools mode_switcher_keys_permissions chmod 644 "$CRT_ROMS/crt/mode_switcher.sh.keys"
  fi
  if [[ -f "$CRTD/Geometry_modeline/crt/gamelist.xml" ]]; then
    write_run 20_crt_tools mode_switcher_gamelist_install cp "$CRTD/Geometry_modeline/crt/gamelist.xml" "$CRT_ROMS/crt/gamelist.xml"
    write_run 20_crt_tools mode_switcher_gamelist_permissions chmod 644 "$CRT_ROMS/crt/gamelist.xml"
  fi
  write_run 20_crt_tools mode_backup_directories mkdir -p \
    /userdata/Batocera-CRT-Script-Backup/mode_backups/{hd_mode,crt_mode}/{boot_configs,emulator_configs,video_settings}
  echo 'Mode Switcher installed successfully.'
else
  # Mode Switcher is part of mandatory CRT Tools. A missing source must not
  # be presented as an optional successful installation.
  write_abort 20_crt_tools mode_switcher_source_missing 1
fi
write_run 20_crt_tools gunlight_plugin_dir mkdir -p /usr/bin/mame/plugins/gunlight
if [[ "$Version_of_batocera" == v44 ]]; then
  for f in gunlight_menu.lua gunlight_save.lua init-v44.lua plugin.json; do
    write_run 20_crt_tools gunlight_plugin_install cp "$CRTD/GunCon2/gunlight/$f" "/usr/bin/mame/plugins/gunlight/${f/-v44/}"
  done
  write_run 20_crt_tools gunlight_plugin_permissions chmod 644 \
    /usr/bin/mame/plugins/gunlight/{gunlight_menu.lua,gunlight_save.lua,init.lua,plugin.json}
fi
write_run 20_crt_tools gunlight_shader_dir mkdir -p /usr/share/batocera/shaders/configs/lightgun-shader
write_run 20_crt_tools gunlight_shader_defaults cp "$CRTD/GunCon2/shader/lightgun-shader/rendering-defaults.yml" /usr/share/batocera/shaders/configs/lightgun-shader/rendering-defaults.yml
write_run 20_crt_tools gunlight_shader_defaults_permissions chmod 644 /usr/share/batocera/shaders/configs/lightgun-shader/rendering-defaults.yml
write_run 20_crt_tools gunlight_shader_preset cp "$CRTD/GunCon2/shader/misc/image-adjustment_lgun.slangp" /usr/share/batocera/shaders/misc/image-adjustment_lgun.slangp
write_run 20_crt_tools gunlight_shader_source cp "$CRTD/GunCon2/shader/misc/shaders/image-adjustment_lgun.slang" /usr/share/batocera/shaders/misc/shaders/image-adjustment_lgun.slang
write_run 20_crt_tools gunlight_shader_permissions chmod 644 \
  /usr/share/batocera/shaders/misc/image-adjustment_lgun.slangp \
  /usr/share/batocera/shaders/misc/shaders/image-adjustment_lgun.slang
if [[ -f /etc/udev/rules.d/99-guncon.rules && ! -f /etc/udev/rules.d/99-guncon.rules.bak ]]; then
  write_run 20_crt_tools guncon_udev_backup cp /etc/udev/rules.d/99-guncon.rules /etc/udev/rules.d/99-guncon.rules.bak
fi
write_run 20_crt_tools guncon_udev_install cp "$CRTD/GunCon2/99-guncon.rules-generic" /etc/udev/rules.d/99-guncon.rules
if [[ -f /usr/bin/guncon2_calibrate.sh && ! -f /usr/bin/guncon2_calibrate.sh.bak ]]; then
  write_run 20_crt_tools guncon_calibrate_backup cp /usr/bin/guncon2_calibrate.sh /usr/bin/guncon2_calibrate.sh.bak
fi
write_generate 20_crt_tools guncon_calibrate_render 755 /usr/bin/guncon2_calibrate.sh \
  sed -e "s/\[guncon2_x\]/$Guncon2_x/g" -e "s/\[guncon2_y\]/$Guncon2_y/g" \
      -e "s/\[guncon2_f\]/$Guncon2_freq/g" -e "s/\[guncon2_res\]/$Guncon2_res/g" \
      "$CRTD/GunCon2/guncon2_calibrate.sh-generic"
if [[ -f /usr/bin/calibrate.py && ! -f /usr/bin/calibrate.py.bak ]]; then
  write_run 20_crt_tools calibrate_python_backup cp /usr/bin/calibrate.py /usr/bin/calibrate.py.bak
fi
if [[ "$ES_rotation" == NORMAL || "$ES_rotation" == INVERTED ]]; then
  write_generate 20_crt_tools calibrate_python_render 755 /usr/bin/calibrate.py \
    sed -e "s/\[guncon2_x\]/$Guncon2_x/g" -e "s/\[guncon2_y\]/$Guncon2_y/g" \
        -e "s/\[guncon2_res\]/$Guncon2_res/g" \
        "$CRTD/GunCon2/calibrate.py-generic"
else
  write_generate 20_crt_tools calibrate_python_render 755 /usr/bin/calibrate.py \
    sed -e "s/\[guncon2_y\]/$Guncon2_x/g" -e "s/\[guncon2_x\]/$Guncon2_y/g" \
        -e "s/\[guncon2_res\]/$Guncon2_res/g" \
        "$CRTD/GunCon2/calibrate.py-generic"
fi
V="$CRTD/install-vnc_server_batocera"
write_run 20_crt_tools vnc_libcrypt_system cp "$V/libcrypt.so.1" /lib/libcrypt.so.1
write_run 20_crt_tools vnc_libraries_install cp "$V"/{libcrypt.so.1,libvncclient.so.1,libvncserver.so.1,libsasl2.so.2} /usr/lib/
write_run 20_crt_tools vnc_executables_install cp "$V"/{vnc,x11vnc,vnc-scaled} /usr/bin/
write_run 20_crt_tools vnc_libcrypt_permissions chmod 0755 /lib/libcrypt.so.1
write_run 20_crt_tools vnc_libraries_permissions chmod 0644 /usr/lib/{libcrypt.so.1,libvncclient.so.1,libvncserver.so.1,libsasl2.so.2}
write_run 20_crt_tools vnc_executables_permissions chmod +x /usr/bin/{vnc,x11vnc,vnc-scaled}
write_run 20_crt_tools overlays_helper_install cp "$CRTD/extra/overlays_overrides.sh" "$CRT_ROMS/crt"
write_run 20_crt_tools overlays_keys_install cp "$CRTD/extra/overlays_overrides.sh.keys" "$CRT_ROMS/crt"
write_run 20_crt_tools overlays_helper_permissions chmod 755 "$CRT_ROMS/crt/overlays_overrides.sh"
write_run 20_crt_tools overlays_keys_permissions chmod 644 "$CRT_ROMS/crt/overlays_overrides.sh.keys"
write_run 20_crt_tools overlays_source_permissions chmod 755 "$CRTD/extra/overlays_overrides_script.sh"
write_run 20_crt_tools multimedia_config_install cp "$CRTD/extra/media_keys/multimedia_keys.conf" /userdata/system/configs/
write_run 20_crt_tools media_scripts_install cp "$CRTD"/extra/media_keys/{esrestart,xrestart,emukill} /usr/bin
# Replace the fixed /tmp staging filename and rm+mv sequence with an isolated
# destination-directory temporary file. The installed executable is identical.
write_generate 20_crt_tools mode_combo_install 755 /usr/bin/crt-mode-switch-combo \
  cat "$CRTD/extra/media_keys/crt-mode-switch-combo"
write_run 20_crt_tools media_watcher_install cp "$CRTD/extra/media_keys/crt-mode-switch-watcher.py" /usr/bin
write_run 20_crt_tools multimedia_config_permissions chmod 644 /userdata/system/configs/multimedia_keys.conf
write_run 20_crt_tools media_script_permissions chmod 755 \
  /usr/bin/{esrestart,xrestart,emukill,crt-mode-switch-combo,crt-mode-switch-watcher.py}
UD_MEDIA_KEYS="$CRTD/extra/media_keys"
write_run 20_crt_tools media_keys_src_dir mkdir -p "$UD_MEDIA_KEYS"
write_run 20_crt_tools mode_combo_source_update cp -f /usr/bin/crt-mode-switch-combo "$UD_MEDIA_KEYS/crt-mode-switch-combo"
write_run 20_crt_tools watcher_source_update cp -f /usr/bin/crt-mode-switch-watcher.py "$UD_MEDIA_KEYS/crt-mode-switch-watcher.py"
write_run 20_crt_tools media_source_permissions chmod 755 "$UD_MEDIA_KEYS/crt-mode-switch-combo" "$UD_MEDIA_KEYS/crt-mode-switch-watcher.py"
write_run 20_crt_tools user_services_dir mkdir -p /userdata/system/services
write_run 20_crt_tools mode_watcher_service cp "$CRTD/extra/media_keys/crt_mode_switch_watcher" /userdata/system/services/crt_mode_switch_watcher
write_run 20_crt_tools mode_watcher_permissions chmod 755 /userdata/system/services/crt_mode_switch_watcher
write_run 20_crt_tools kodi_launcher_install cp "$CRTD/extra/Kodi/Kodi.sh" /userdata/roms/ports
write_run 20_crt_tools kodi_launcher_permissions chmod 755 /userdata/roms/ports/Kodi.sh
if declare -F diag_probe >/dev/null 2>&1; then
  diag_probe 20_crt_tools es_crt_registration_file /userdata/system/configs/emulationstation/es_systems_crt.cfg
  diag_probe 20_crt_tools crt_launcher_file "$CRT_ROMS/crt/geometry.sh"
  diag_probe 20_crt_tools guncon_udev_file /etc/udev/rules.d/99-guncon.rules
  diag_probe 20_crt_tools watcher_service_file /userdata/system/services/crt_mode_switch_watcher
fi
# Save only after step 22 finishes the required CRT and batocera.conf writes.
# Single-boot native saver, Phase 2 dedicated CRT saver: 24_finish.sh.
if declare -F log_event >/dev/null 2>&1; then
  log_event INFO 20_crt_tools overlay_save_deferred stage POST_SAVE || :
fi
