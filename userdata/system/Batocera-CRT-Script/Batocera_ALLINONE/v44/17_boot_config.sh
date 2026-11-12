# Batocera-CRT-Script v44 - step 17: boot config
# /boot/batocera-boot.conf (drivers, es.resolution, splash) and syslinux.cfg
# (dual-boot: LABEL crt APPEND only; single boot: rendered from the template).
b71; echo "##               mount -o remount,rw /boot                          ##" | tee -a "$CRT_LOG"; b71
write_run 17_boot_config boot_remount_rw mount -o remount,rw /boot
if [ ! -f /boot/batocera-boot.conf.bak ]; then
  write_run 17_boot_config boot_conf_backup cp /boot/batocera-boot.conf /boot/batocera-boot.conf.bak
fi
write_run 17_boot_config boot_config_stage cp /boot/batocera-boot.conf /boot/batocera-boot.conf.tmp
if [ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]; then
	if [ "$Drivers_Name_Nvidia_CHOICE" == "true" ]; then
		sed -e 's/.*nvidia-driver=.*/nvidia-driver=true/' -e 's/.*amdgpu=.*/#amdgpu=true/' /boot/batocera-boot.conf > /boot/batocera-boot.conf.tmp || write_abort 17_boot_config driver_config_render "$?"
	elif [ "$Drivers_Name_Nvidia_CHOICE" == "legacy580" ]; then
		sed -e 's/.*nvidia-driver=.*/nvidia-driver=legacy580/' -e 's/.*amdgpu=.*/#amdgpu=true/' /boot/batocera-boot.conf > /boot/batocera-boot.conf.tmp || write_abort 17_boot_config driver_config_render "$?"
	elif [ "$Drivers_Name_Nvidia_CHOICE" == "legacy470" ]; then
		sed -e 's/.*nvidia-driver=.*/nvidia-driver=legacy470/' -e 's/.*amdgpu=.*/#amdgpu=true/' /boot/batocera-boot.conf > /boot/batocera-boot.conf.tmp || write_abort 17_boot_config driver_config_render "$?"
	else write_abort 17_boot_config invalid_nvidia_driver 1; fi
else
	if [ "$Drivers_Nvidia_CHOICE" == "NOUVEAU" ]&&([ "$Version_of_batocera" == "v44" ]); then
		sed -e 's/.*nvidia-driver=.*/nvidia-driver=false/' -e 's/.*amdgpu=.*/#amdgpu=true/' /boot/batocera-boot.conf > /boot/batocera-boot.conf.tmp || write_abort 17_boot_config driver_config_render "$?"
	else
		if [ "$TYPE_OF_CARD" == "AMD/ATI" ]&&([ "$Version_of_batocera" == "v44" ]); then
			if [ "$drivers_type" == "AMDGPU" ]; then
				sed -e 's/.*nvidia-driver=.*/#nvidia-driver=true/' -e 's/.*amdgpu=.*/amdgpu=true/' /boot/batocera-boot.conf > /boot/batocera-boot.conf.tmp || write_abort 17_boot_config driver_config_render "$?"
			else
				sed -e 's/.*nvidia-driver=.*/#nvidia-driver=true/' -e 's/.*amdgpu=.*/amdgpu=false/' /boot/batocera-boot.conf > /boot/batocera-boot.conf.tmp || write_abort 17_boot_config driver_config_render "$?"
			fi
		else sed -e 's/.*nvidia-driver=.*/#nvidia-driver=true/' -e 's/.*amdgpu=.*/#amdgpu=true/' /boot/batocera-boot.conf > /boot/batocera-boot.conf.tmp || write_abort 17_boot_config driver_config_render "$?"; fi
	fi
fi
write_run 17_boot_config boot_config_commit cp /boot/batocera-boot.conf.tmp /boot/batocera-boot.conf
write_run 17_boot_config boot_config_commit_readback cmp -s /boot/batocera-boot.conf.tmp /boot/batocera-boot.conf
write_run 17_boot_config boot_config_temp_cleanup rm -f /boot/batocera-boot.conf.tmp
if [ "$BOOT_RESOLUTION" == "1" ]; then
  write_run 17_boot_config boot_es_resolution sed -i "s/.*es.resolution=.*/$Resolution_es/" /boot/batocera-boot.conf
else
  write_run 17_boot_config boot_es_resolution sed -i 's/.*es.resolution=.*/#es.resolution=640x480/' /boot/batocera-boot.conf
fi
if [ "$TYPE_OF_CARD" == "NVIDIA" ]; then
  write_run 17_boot_config boot_splash sed -i 's/.*splash.screen.enabled=.*/splash.screen.enabled=0/' /boot/batocera-boot.conf
else
  write_run 17_boot_config boot_splash sed -i 's/.*splash.screen.enabled=.*/#splash.screen.enabled=0/' /boot/batocera-boot.conf
fi
write_run 17_boot_config boot_conf_permissions chmod 755 /boot/batocera-boot.conf
if declare -F diag_probe >/dev/null 2>&1; then
  diag_probe 17_boot_config boot_conf_present /boot/batocera-boot.conf
fi
# The Sea Islands prompt reboots before this file runs. The next install rebuilds
# syslinux from scratch, so keep the radeon parameters on that boot line.
if [ -f "${SEA_ISLANDS_RADEON_MARKER:-/userdata/system/Batocera-CRT-Script/.sea_islands_radeon}" ]; then
  case " ${drivers_amd:-} " in
    *" radeon.cik_support=1 "*) ;;
    *) drivers_amd="${drivers_amd:+$drivers_amd }${SEA_ISLANDS_RADEON_PARAMS:-amdgpu.cik_support=0 radeon.cik_support=1}" ;;
  esac
  echo "Sea Islands: keeping ${drivers_amd} on the CRT boot line" | tee -a "$CRT_LOG"
fi
if [ "$IS_DUALBOOT_INSTALL" = true ]; then
  CRT_APPEND_LINE="label=BATOCERA console=tty3 quiet loglevel=0 vt.global_cursor_default=0 mitigations=off ${drivers_amd} ${polling_rate} drm.edid_firmware=${video_output}:edid/${monitor_firmware}.bin video=${video_output}:${boot_resolution}"
  for f in /boot/EFI/batocera/syslinux.cfg \
           /boot/boot/syslinux.cfg \
           /boot/boot/syslinux/syslinux.cfg; do
    [ -f "$f" ] || continue
    if ! grep -q '^LABEL crt$' "$f"; then
      write_abort 17_boot_config missing_crt_label 1
    fi
    awk -v newappend="$CRT_APPEND_LINE" '
      /^LABEL crt$/ { in_crt=1 }
      /^LABEL / && !/^LABEL crt$/ { in_crt=0 }
      in_crt && /^[[:space:]]*APPEND / { print "\tAPPEND " newappend; next }
      { print }
    ' "$f" > "${f}.tmp" || write_abort 17_boot_config crt_syslinux_render "$?"
    write_run 17_boot_config crt_syslinux_commit mv "${f}.tmp" "$f"
    write_run 17_boot_config crt_syslinux_permissions chmod 755 "$f"
    write_run 17_boot_config crt_syslinux_readback write_append_matches "$f" "$CRT_APPEND_LINE"
    echo "Updated LABEL crt APPEND in $f (dual-boot)" \
      | tee -a "$CRT_LOG"
  done
else
  TMP_SYS="/tmp/syslinux.cfg.new"
  sed -e "s/\[amdgpu_drivers\]/$drivers_amd/g" \
      -e "s/\[card_output\]/$video_output/g" \
      -e "s/\[monitor\]/$monitor_firmware.bin/g" \
      -e "s|\[card_display\]|$video_output|g" \
      -e "s/\[usb_polling\]/$polling_rate/g" \
      -e "s/\[boot_resolution\]/$boot_resolution/g" \
      "$CRTD"/Boot_configs/syslinux.cfg-generic-Batocera > "$TMP_SYS" \
    || write_abort 17_boot_config primary_syslinux_render "$?"
  [ -s "$TMP_SYS" ] || write_abort 17_boot_config primary_syslinux_empty 1
  PRIMARY="/boot/boot/syslinux.cfg"
  write_run 17_boot_config primary_syslinux_mkdir mkdir -p "$(dirname "$PRIMARY")"
  if [ -f "$PRIMARY" ] && [ ! -f "${PRIMARY}.initial" ]; then
    write_run 17_boot_config primary_syslinux_initial cp "$PRIMARY" "${PRIMARY}.initial"
  fi
  if [ -f "$PRIMARY" ]; then write_run 17_boot_config primary_syslinux_backup cp "$PRIMARY" "${PRIMARY}.bak"; fi
  write_run 17_boot_config primary_syslinux_commit cp "$TMP_SYS" "$PRIMARY"
  write_run 17_boot_config primary_syslinux_permissions chmod 755 "$PRIMARY"
  write_run 17_boot_config primary_syslinux_readback cmp -s "$TMP_SYS" "$PRIMARY"
  echo "Updated $PRIMARY" | tee -a "$CRT_LOG"
  MIRROR_DIRS=(
    "/boot/EFI" "/boot/EFI/BOOT" "/boot/EFI/batocera" "/boot/boot/syslinux"
  )
  for d in "${MIRROR_DIRS[@]}"; do
    [ -d "$d" ] || continue; tgt="$d/syslinux.cfg"
    if [ -f "$tgt" ] && [ ! -f "${tgt}.initial" ]; then
      write_run 17_boot_config mirror_syslinux_initial cp "$tgt" "${tgt}.initial"
    fi
    if [ -f "$tgt" ]; then write_run 17_boot_config mirror_syslinux_backup cp "$tgt" "${tgt}.bak"; fi
    write_run 17_boot_config mirror_syslinux_commit cp "$TMP_SYS" "$tgt"
    write_run 17_boot_config mirror_syslinux_permissions chmod 755 "$tgt"
    write_run 17_boot_config mirror_syslinux_readback cmp -s "$TMP_SYS" "$tgt"
    echo "Updated $tgt" | tee -a "$CRT_LOG"
  done
fi
