# Batocera-CRT-Script v44 - step 21: event scripts
# Preserve the original selected modelines, file names, and script modes.
if [[ "$Drivers_Nvidia_CHOICE" == Nvidia_Drivers ]]; then
  if [[ -f /userdata/system/99-nvidia.conf ]]; then
    write_run 21_event_scripts nvidia_monitor_backup cp /userdata/system/99-nvidia.conf /userdata/system/99-nvidia.conf.bak
  fi
  case "$CRT_Freq" in
    15KHz)
      write_generate 21_event_scripts nvidia_monitor_generate 644 /userdata/system/99-nvidia.conf \
        sed -e "s/.*Modeline.*/    Modeline            $MODELINE_CUSTOM/" \
            -e "s/\[card_display\]/$video_modeline/g" \
            "$CRTD/System_configs/Nvidia/99-nvidia.conf-generic_15"
      ;;
    25KHz)
      write_generate 21_event_scripts nvidia_monitor_generate 644 /userdata/system/99-nvidia.conf \
        sed -e "s/.*Modeline.*/    Modeline            $MODELINE_CUSTOM/" \
            -e "s/\[card_display\]/$video_modeline/g" \
            "$CRTD/System_configs/Nvidia/99-nvidia.conf-generic_25"
      ;;
    31KHz)
      write_generate 21_event_scripts nvidia_monitor_generate 644 /userdata/system/99-nvidia.conf \
        sed -e "s/\[card_display\]/$video_modeline/g" \
            "$CRTD/System_configs/Nvidia/99-nvidia.conf-generic_31"
      ;;
    *) write_abort 21_event_scripts unsupported_crt_frequency 1 ;;
  esac
  write_run 21_event_scripts nvidia_monitor_snapshot cp /userdata/system/99-nvidia.conf /userdata/system/99-nvidia.conf.bak
else
  if [[ -f /userdata/system/99-nvidia.conf ]]; then
    write_run 21_event_scripts nvidia_monitor_retire_backup cp /userdata/system/99-nvidia.conf /userdata/system/99-nvidia.conf.bak
    write_run 21_event_scripts nvidia_monitor_remove rm /userdata/system/99-nvidia.conf
  fi
fi
write_run 21_event_scripts scripts_directory mkdir -p /userdata/system/scripts
if [[ "$BOOT_RESOLUTION" == 1 ]]; then
  first_script_resolution="$RES_EDID"
else
  first_script_resolution="$RES_EDID_SCANNING"
fi
write_generate 21_event_scripts first_script_generate 755 /userdata/system/scripts/first_script.sh \
  sed -e "s/\[display_mame_rotation\]/$display_mame_rotate/g" \
      -e "s/\[display_fbneo_rotation\]/$display_fbneo_rotate/g" \
      -e "s/\[display_libretro_rotation\]/$display_libretro_rotate/g" \
      -e "s/\[display_standalone_rotation\]/$display_standalone_rotate/g" \
      -e "s/\[display_ES_rotation\]/$display_rotate/g" \
      -e "s/\[card_display\]/$video_modeline/g" \
      -e "s/\[es_resolution\]/$first_script_resolution/g" \
      "$CRTD/System_configs/First_script/first_script.sh-generic-v42"
write_generate 21_event_scripts guncon_event_generate 755 /userdata/system/scripts/1_GunCon2.sh \
  sed -e "s/\[card_display\]/$video_modeline/g" \
      "$CRTD/System_configs/First_script/1_GunCon2.sh-generic"
write_generate 21_event_scripts guncon_calibration_generate 755 "$CRT_ROMS/crt/GunCon2_Calibration.sh" \
  sed -e "s/\[card_display\]/$video_modeline/g" \
      "$CRTD/GunCon2/GunCon2_Calibration.sh-generic"
if declare -F diag_probe >/dev/null 2>&1; then
  diag_probe 21_event_scripts first_script_file /userdata/system/scripts/first_script.sh
  diag_probe 21_event_scripts guncon_event_file /userdata/system/scripts/1_GunCon2.sh
  diag_probe 21_event_scripts guncon_calibration_file "$CRT_ROMS/crt/GunCon2_Calibration.sh"
fi
