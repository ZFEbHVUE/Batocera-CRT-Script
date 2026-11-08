# Batocera-CRT-Script v44 - step 17: boot config
# /boot/batocera-boot.conf (drivers, es.resolution, splash) and syslinux.cfg
# (dual-boot: LABEL crt APPEND only; single boot: rendered from the template).
b71; echo "##               mount -o remount, rw /boot                          ##" | tee -a "$CRT_LOG"; b71
mount -o remount, rw /boot
if [ ! -f "/boot/batocera-boot.conf.bak" ];then cp /boot/batocera-boot.conf /boot/batocera-boot.conf.bak; fi
cp /boot/batocera-boot.conf /boot/batocera-boot.conf.tmp
if [ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]; then
	if [ "$Drivers_Name_Nvidia_CHOICE" == "true" ]; then
		sed -e 's/.*nvidia-driver=.*/nvidia-driver=true/' -e 's/.*amdgpu=.*/#amdgpu=true/' /boot/batocera-boot.conf > /boot/batocera-boot.conf.tmp
	elif [ "$Drivers_Name_Nvidia_CHOICE" == "legacy580" ]; then
		sed -e 's/.*nvidia-driver=.*/nvidia-driver=legacy580/' -e 's/.*amdgpu=.*/#amdgpu=true/' /boot/batocera-boot.conf > /boot/batocera-boot.conf.tmp
	elif [ "$Drivers_Name_Nvidia_CHOICE" == "legacy470" ]; then
		sed -e 's/.*nvidia-driver=.*/nvidia-driver=legacy470/' -e 's/.*amdgpu=.*/#amdgpu=true/' /boot/batocera-boot.conf > /boot/batocera-boot.conf.tmp
	else echo "problems of Nvidia driver name"; fi
else
	if [ "$Drivers_Nvidia_CHOICE" == "NOUVEAU" ]&&([ "$Version_of_batocera" == "v44" ]); then
		sed -e 's/.*nvidia-driver=.*/nvidia-driver=false/' -e 's/.*amdgpu=.*/#amdgpu=true/' /boot/batocera-boot.conf > /boot/batocera-boot.conf.tmp
	else
		if [ "$TYPE_OF_CARD" == "AMD/ATI" ]&&([ "$Version_of_batocera" == "v44" ]); then
			if [ "$drivers_type" == "AMDGPU" ]; then
				sed -e 's/.*nvidia-driver=.*/#nvidia-driver=true/' -e 's/.*amdgpu=.*/amdgpu=true/' /boot/batocera-boot.conf > /boot/batocera-boot.conf.tmp
			else
				sed -e 's/.*nvidia-driver=.*/#nvidia-driver=true/' -e 's/.*amdgpu=.*/amdgpu=false/' /boot/batocera-boot.conf > /boot/batocera-boot.conf.tmp
			fi
		else sed -e 's/.*nvidia-driver=.*/#nvidia-driver=true/' -e 's/.*amdgpu=.*/#amdgpu=true/' /boot/batocera-boot.conf > /boot/batocera-boot.conf.tmp; fi
	fi
fi
cp /boot/batocera-boot.conf.tmp /boot/batocera-boot.conf; rm /boot/batocera-boot.conf.tmp
if [ "$BOOT_RESOLUTION" == "1" ]; then
	sed -i "s/.*es.resolution=.*/$Resolution_es/" /boot/batocera-boot.conf
else sed -i 's/.*es.resolution=.*/#es.resolution=640x480/' /boot/batocera-boot.conf; fi
if [ "$TYPE_OF_CARD" == "NVIDIA" ]; then
	sed -i "s/.*splash.screen.enabled=.*/splash.screen.enabled=0/" /boot/batocera-boot.conf
else sed -i "s/.*splash.screen.enabled=.*/#splash.screen.enabled=0/" /boot/batocera-boot.conf; fi
chmod 755 /boot/batocera-boot.conf; mount -o remount,rw /boot 2>/dev/null || true
if [ "$IS_DUALBOOT_INSTALL" = true ]; then
  CRT_APPEND_LINE="label=BATOCERA console=tty3 quiet loglevel=0 vt.global_cursor_default=0 mitigations=off ${drivers_amd} ${polling_rate} drm.edid_firmware=${video_output}:edid/${monitor_firmware}.bin video=${video_output}:${boot_resolution}"
  for f in /boot/EFI/batocera/syslinux.cfg \
           /boot/boot/syslinux.cfg \
           /boot/boot/syslinux/syslinux.cfg; do
    [ -f "$f" ] || continue
    if ! grep -q '^LABEL crt' "$f"; then
      echo "WARNING: LABEL crt missing in $f — skipping APPEND update" \
        | tee -a "$CRT_LOG"
      continue
    fi
    awk -v newappend="$CRT_APPEND_LINE" '
      /^LABEL crt$/ { in_crt=1 }
      /^LABEL / && !/^LABEL crt$/ { in_crt=0 }
      in_crt && /^[[:space:]]*APPEND / { print "\tAPPEND " newappend; next }
      { print }
    ' "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
    chmod 755 "$f"
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
      "$CRTD"/Boot_configs/syslinux.cfg-generic-Batocera \
      > "$TMP_SYS"
  PRIMARY="/boot/boot/syslinux.cfg"; mkdir -p "$(dirname "$PRIMARY")"
  if [ -f "$PRIMARY" ] && [ ! -f "${PRIMARY}.initial" ]; then cp "$PRIMARY" "${PRIMARY}.initial"; fi
  [ -f "$PRIMARY" ] && cp "$PRIMARY" "${PRIMARY}.bak"; cp "$TMP_SYS" "$PRIMARY"; chmod 755 "$PRIMARY"
  echo "Updated $PRIMARY" | tee -a "$CRT_LOG"
  MIRROR_DIRS=(
    "/boot/EFI" "/boot/EFI/BOOT" "/boot/EFI/batocera" "/boot/boot/syslinux"
  )
  for d in "${MIRROR_DIRS[@]}"; do
    [ -d "$d" ] || continue; tgt="$d/syslinux.cfg"
    if [ -f "$tgt" ] && [ ! -f "${tgt}.initial" ]; then cp "$tgt" "${tgt}.initial"; fi
    [ -f "$tgt" ] && cp "$tgt" "${tgt}.bak"; cp "$TMP_SYS" "$tgt"; chmod 755 "$tgt"
    echo "Updated $tgt" | tee -a "$CRT_LOG"
  done
fi
