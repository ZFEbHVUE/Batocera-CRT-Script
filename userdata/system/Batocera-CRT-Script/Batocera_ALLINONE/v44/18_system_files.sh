# Batocera-CRT-Script v44 - step 18: system files
# Keep all existing destinations and selected variants. No overlay saving here.
for driver_conf in 20-amdgpu.conf 20-radeon.conf; do
  if [[ -f "/etc/X11/xorg.conf.d/$driver_conf" && ! -f "/etc/X11/xorg.conf.d/$driver_conf.bak" ]]; then
    write_run 18_system_files xorg_previous_backup cp "/etc/X11/xorg.conf.d/$driver_conf" "/etc/X11/xorg.conf.d/$driver_conf.bak"
  fi
  if [[ -e "/etc/X11/xorg.conf.d/$driver_conf" || -L "/etc/X11/xorg.conf.d/$driver_conf" ]]; then
    write_run 18_system_files xorg_old_driver_remove rm -f -- "/etc/X11/xorg.conf.d/$driver_conf"
  fi
done
write_run 18_system_files xorg_modesetting_install cp "$CRTD/etc_configs/Monitors_config/20-modesetting.conf" /etc/X11/xorg.conf.d/20-modesetting.conf
write_run 18_system_files xorg_modesetting_permissions chmod 644 /etc/X11/xorg.conf.d/20-modesetting.conf
python_directory=$(find /usr/lib/ -maxdepth 1 -type d -name 'python*' -exec basename {} \; -quit) || write_abort 18_system_files python_path_scan "$?"
[[ "$python_directory" =~ ^python[0-9]+\.[0-9]+$ ]] || write_abort 18_system_files python_path_invalid 1
new_path="/usr/lib/${python_directory}/site-packages/batocera_launch/devices/"
if [[ -f "${new_path}video.py" && ! -f "${new_path}video.py.bak" ]]; then
  write_run 18_system_files video_original_backup cp "${new_path}video.py" "${new_path}video.py.bak"
fi
case "$Version_of_batocera" in
  v44)
    write_run 18_system_files configgen_video_install cp "$CRTD/UsrBin_configs/Configgen/Video.py-v44_ZFEbHVUE" "${new_path}video.py"
    write_run 18_system_files configgen_video_permissions chmod 755 "${new_path}video.py"
    if [[ "$Drivers_Nvidia_CHOICE" == Nvidia_Drivers ]]; then
      write_run 18_system_files nvidia_resolution_install cp "$CRTD/UsrBin_configs/batocera-resolution-v44_Nvidia_driver_MYZAR_ZFEbHVUE-MultiScreen" /usr/bin/batocera-resolution
    else
      write_run 18_system_files standard_resolution_install cp "$CRTD/UsrBin_configs/batocera-resolution-v44_MYZAR_ZFEbHVUE-MultiScreen" /usr/bin/batocera-resolution
    fi
    write_run 18_system_files emulationstation_install cp "$CRTD/UsrBin_configs/emulationstation-standalone-v44_ZFEbHVUE-MultiScreen" /usr/bin/emulationstation-standalone
    write_run 18_system_files resolution_permissions chmod 755 /usr/bin/batocera-resolution
    write_run 18_system_files es_permissions chmod 755 /usr/bin/emulationstation-standalone
    if [[ "${CRT_KEEP_GEOMETRY:-0}" == 1 ]]; then
      [[ -s "${CRT_GEOMETRY_SNAPSHOT:-}" && ! -L "${CRT_GEOMETRY_SNAPSHOT:-}" ]] || write_abort 18_system_files custom_geometry_snapshot_missing 1
      write_generate 18_system_files switchres_preserved 755 /etc/switchres.ini \
        sed -e "s/^[[:space:]]*dotclock_min[[:space:]].*/    dotclock_min              $dotclock_min/" \
            -e "s/^[[:space:]]*super_width[[:space:]].*/\tsuper_width               $super_width/" \
            -e "s/^[[:space:]]*interlace_force_even[[:space:]].*/        interlace_force_even      $IFE/" \
            "$CRT_GEOMETRY_SNAPSHOT"
      echo "Kept custom geometry. Wrote dotclock ${dotclock_min} and super-res ${super_width}." >> "$CRT_LOG" || :
    else
      write_generate 18_system_files switchres_render 755 /etc/switchres.ini \
        sed -e "s/\[monitor-name\]/$monitor_name_MAME/g" \
            -e "s/\[super_width\]/$super_width/g" \
            -e "s/\[dotclock_min_value\]/$dotclock_min/g" \
            -e "s/.*interlace_force_even   .*/        interlace_force_even      $IFE/" \
            "$CRTD/etc_configs/switchres.ini-generic-v36"
    fi
    write_run 18_system_files monitor_range_install cp "$CRTD/UsrBin_configs/get_monitorRange" /usr/bin/get_monitorRange
    write_run 18_system_files monitor_range_permissions chmod 755 /usr/bin/get_monitorRange
    ;;
  *) write_abort 18_system_files unsupported_version 1 ;;
esac
write_run 18_system_files switchres_backup cp /etc/switchres.ini /etc/switchres.ini.bak
if declare -F diag_probe >/dev/null 2>&1; then
  diag_probe 18_system_files modesetting_config /etc/X11/xorg.conf.d/20-modesetting.conf
  diag_probe 18_system_files switchres_ini /etc/switchres.ini
  diag_probe 18_system_files es_binary /usr/bin/emulationstation-standalone
  diag_probe 18_system_files resolution_tool /usr/bin/batocera-resolution
fi
for s in stop start; do
  if [[ ! -f "/usr/bin/$s" ]]; then
    write_generate 18_system_files "${s}_wrapper" 755 "/usr/bin/$s" \
      printf '#!/bin/bash\n/etc/init.d/S31emulationstation %s\n' "$s"
  fi
done
if [[ -f /usr/share/batocera/splash/splash.srt ]]; then
  write_run 18_system_files splash_subtitle_backup mv /usr/share/batocera/splash/splash.srt /usr/share/batocera/splash/splash.srt.bak
fi
if [[ -f /usr/share/batocera/splash/boot-logo.png && ! -f /usr/share/batocera/splash/boot-logo.png.bak ]]; then
  write_run 18_system_files splash_logo_backup cp /usr/share/batocera/splash/boot-logo.png /usr/share/batocera/splash/boot-logo.png.bak
fi
write_run 18_system_files splash_default_copy cp "$CRTD/Boot_logos/boot-logo.png" /usr/share/batocera/splash/boot-logo.png
case "$display_rotate" in
  right) write_run 18_system_files splash_right_copy cp "$CRTD/Boot_logos/boot-logo_90.png" /usr/share/batocera/splash/boot-logo.png ;;
  inverted) write_run 18_system_files splash_inverted_copy cp "$CRTD/Boot_logos/boot-logo_180.png" /usr/share/batocera/splash/boot-logo.png ;;
  left) write_run 18_system_files splash_left_copy cp "$CRTD/Boot_logos/boot-logo_270.png" /usr/share/batocera/splash/boot-logo.png ;;
esac
