#######################################################################
###                 Start of usb polling rate config               ####
#######################################################################
echo ""
echo "#######################################################################"
echo "##                                                                   ##"
echo "##                      ADVANCED CONFIGURATION       3/3             ##" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
echo "##                                                                   ##"
echo "##                         USB FAST POLLING                          ##"
echo "##                                                                   ##"
echo "##  Adjust the USB polling rate for controllers/encoders to reduce   ##"
echo "##  input latency. Higher rates can improve responsiveness but may   ##"
echo "##  increase CPU usage or cause issues on some devices.              ##"
echo "##                                                                   ##"
echo "##  If you are unsure, leave this unchanged. Batocera’s default is   ##"
echo "##  generally optimal. Press ENTER to keep the default setting.      ##"
echo "##                                                                   ##"
echo "#######################################################################"
echo ""
declare -a usb_selector=( "Activate(reduce input lag)" "Keep default" )
for var in "${!usb_selector[@]}" ; do echo "			$((var+1)) : ${usb_selector[$var]}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log; done
echo ""
echo "#######################################################################"
echo "##                 Select your USB polling rate option               ##"
echo "##           (Press ENTER to keep the default configuration)         ##"
echo "#######################################################################"
echo -n "                                  "
read p_rate
	while [[ ! ${p_rate} =~ ^[1-$((var+1))]$ ]] && [[ "$p_rate" != "" ]] ; do
		echo -n "Select option 1 to $((var+1)) or ENTER to bypass this configuration:"
		read p_rate
	done
if [ -z "$p_rate" ] ; then 
	echo -e "                    your choice is :${GREEN} Batocera default usb polling rate${NOCOLOR}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
	polling_rate="usbhid.jspoll=0 xpad.cpoll=0"
elif [ "x$p_rate" != "x0" ] ; then
	echo -e "                    your choice is :${GREEN}  ${usb_selector[$p_rate-1]}${NOCOLOR}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
	case $p_rate in
		1) polling_rate="usbhid.jspoll=1 xpad.cpoll=1";;
		*) polling_rate="usbhid.jspoll=0 xpad.cpoll=0";;
	esac
fi

#############################################################################
## Make the boot writable
#############################################################################
echo "#######################################################################"
echo "##               mount -o remount, rw /boot                          ##" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
echo "#######################################################################"

mount -o remount, rw /boot

#############################################################################
# first time using the script save the batocera-boot.conf batocera-boot.conf.bak
#############################################################################
if [ ! -f "/boot/batocera-boot.conf.bak" ];then
	cp /boot/batocera-boot.conf /boot/batocera-boot.conf.bak
fi

cp /boot/batocera-boot.conf  /boot/batocera-boot.conf.tmp

#############################################################################
# choose #nvidia-driver (NOUVEAU) or nvidia-driver=true (nvidia driver)
#############################################################################
if [ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]; then
	if   [ "$Drivers_Name_Nvidia_CHOICE" == "true" ]; then
		sed -e 's/.*nvidia-driver=.*/nvidia-driver=true/' -e 's/.*amdgpu=.*/#amdgpu=true/' 	/boot/batocera-boot.conf > /boot/batocera-boot.conf.tmp
	elif [ "$Drivers_Name_Nvidia_CHOICE" == "legacy580" ]; then
		sed -e 's/.*nvidia-driver=.*/nvidia-driver=legacy580/' -e 's/.*amdgpu=.*/#amdgpu=true/' 	/boot/batocera-boot.conf > /boot/batocera-boot.conf.tmp
	elif [ "$Drivers_Name_Nvidia_CHOICE" == "legacy470" ]; then
		sed -e 's/.*nvidia-driver=.*/nvidia-driver=legacy470/' -e 's/.*amdgpu=.*/#amdgpu=true/' 	/boot/batocera-boot.conf > /boot/batocera-boot.conf.tmp
	else
		echo "problems of Nvidia driver name"
	fi	
else
	if [ "$Drivers_Nvidia_CHOICE" == "NOUVEAU" ]&&([ "$Version_of_batocera" == "v44" ]); then
		sed -e 's/.*nvidia-driver=.*/nvidia-driver=false/' -e 's/.*amdgpu=.*/#amdgpu=true/' 	 	/boot/batocera-boot.conf > /boot/batocera-boot.conf.tmp
	else
		if [ "$TYPE_OF_CARD" == "AMD/ATI" ]&&([ "$Version_of_batocera" == "v44" ]); then

			if [ "$drivers_type" == "AMDGPU" ]; then
				sed -e 's/.*nvidia-driver=.*/#nvidia-driver=true/' -e 's/.*amdgpu=.*/amdgpu=true/'	/boot/batocera-boot.conf > /boot/batocera-boot.conf.tmp
			else
				sed -e 's/.*nvidia-driver=.*/#nvidia-driver=true/' -e 's/.*amdgpu=.*/amdgpu=false/' 	/boot/batocera-boot.conf > /boot/batocera-boot.conf.tmp
			fi
		else
			sed -e 's/.*nvidia-driver=.*/#nvidia-driver=true/' -e 's/.*amdgpu=.*/#amdgpu=true/' 		/boot/batocera-boot.conf > /boot/batocera-boot.conf.tmp
		fi
	fi
fi



cp /boot/batocera-boot.conf.tmp  /boot/batocera-boot.conf
rm /boot/batocera-boot.conf.tmp 

if [ "$BOOT_RESOLUTION" == "1" ]; then
	sed -i "s/.*es.resolution=.*/$Resolution_es/" 		/boot/batocera-boot.conf
else
	sed -i 's/.*es.resolution=.*/#es.resolution=640x480/' 	/boot/batocera-boot.conf 
fi

if [ "$TYPE_OF_CARD" == "NVIDIA" ]; then
	sed -i "s/.*splash.screen.enabled=.*/splash.screen.enabled=0/" /boot/batocera-boot.conf
else
	sed -i "s/.*splash.screen.enabled=.*/#splash.screen.enabled=0/" /boot/batocera-boot.conf
fi



chmod 755 /boot/batocera-boot.conf

#############################################################################
## Build/copy syslinux.cfg for your boot layout (v42-safe) START 		   ##
#############################################################################

mount -o remount,rw /boot 2>/dev/null || true

if [ "$IS_DUALBOOT_INSTALL" = true ]; then
  #########################################################################
  # Dual-boot: preserve the multi-entry syslinux.cfg structure.
  # Only inject CRT kernel params into the LABEL crt APPEND line.
  #########################################################################
  CRT_APPEND_LINE="label=BATOCERA console=tty3 quiet loglevel=0 vt.global_cursor_default=0 mitigations=off ${drivers_amd} ${polling_rate} drm.edid_firmware=${video_output}:edid/${monitor_firmware}.bin video=${video_output}:${boot_resolution}"

  for f in /boot/EFI/batocera/syslinux.cfg \
           /boot/boot/syslinux.cfg \
           /boot/boot/syslinux/syslinux.cfg; do
    [ -f "$f" ] || continue
    if ! grep -q '^LABEL crt' "$f"; then
      echo "WARNING: LABEL crt missing in $f — skipping APPEND update" \
        | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
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
      | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
  done

else
  #########################################################################
  # Single-boot (stock X11): overwrite syslinux.cfg from template
  #########################################################################

  # 1) Render from template into a temp file
  TMP_SYS="/tmp/syslinux.cfg.new"
  sed -e "s/\[amdgpu_drivers\]/$drivers_amd/g" \
      -e "s/\[card_output\]/$video_output/g" \
      -e "s/\[monitor\]/$monitor_firmware.bin/g" \
      -e "s|\[card_display\]|$video_output|g" \
      -e "s/\[usb_polling\]/$polling_rate/g" \
      -e "s/\[boot_resolution\]/$boot_resolution/g" \
      /userdata/system/Batocera-CRT-Script/Boot_configs/syslinux.cfg-generic-Batocera \
      > "$TMP_SYS"

  # 2) Primary destination (exists on both legacy BIOS & UEFI)
  PRIMARY="/boot/boot/syslinux.cfg"
  mkdir -p "$(dirname "$PRIMARY")"
  if [ -f "$PRIMARY" ] && [ ! -f "${PRIMARY}.initial" ]; then
    cp "$PRIMARY" "${PRIMARY}.initial"
  fi
  [ -f "$PRIMARY" ] && cp "$PRIMARY" "${PRIMARY}.bak"
  cp "$TMP_SYS" "$PRIMARY"
  chmod 755 "$PRIMARY"
  echo "Updated $PRIMARY" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log

  #########################################################################
  ## Copy syslinux for EFI and additional legacy paths (only if present)
  #########################################################################

  MIRROR_DIRS=(
    "/boot/EFI"                # -> /boot/EFI/syslinux.cfg
    "/boot/EFI/BOOT"           # -> /boot/EFI/BOOT/syslinux.cfg
    "/boot/EFI/batocera"       # -> /boot/EFI/batocera/syslinux.cfg
    "/boot/boot/syslinux"      # -> /boot/boot/syslinux/syslinux.cfg
  )

  for d in "${MIRROR_DIRS[@]}"; do
    [ -d "$d" ] || continue
    tgt="$d/syslinux.cfg"
    if [ -f "$tgt" ] && [ ! -f "${tgt}.initial" ]; then
      cp "$tgt" "${tgt}.initial"
    fi
    [ -f "$tgt" ] && cp "$tgt" "${tgt}.bak"
    cp "$TMP_SYS" "$tgt"
    chmod 755 "$tgt"
    echo "Updated $tgt" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
  done
fi
#############################################################################
## Build/copy syslinux.cfg for your boot layout (v42-safe) END			   ##
#############################################################################
