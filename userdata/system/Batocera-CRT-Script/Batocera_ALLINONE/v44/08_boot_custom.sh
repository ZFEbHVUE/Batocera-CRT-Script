# Batocera-CRT-Script v44 - step 08: boot custom
# /boot/boot-custom.sh installer (AMD and nouveau only), called by the finish step.
maybe_install_boot_custom_sh() {
  local LOG_FILE="${CRT_LOG}"; local SRC="${CRTD}/UsrBin_configs/boot-custom.sh"; local DST="/boot/boot-custom.sh"
  local intel_gpu=0
  for v in /sys/class/drm/card*/device/vendor; do
    if [ -f "$v" ] && grep -qi '^0x8086' "$v"; then
      intel_gpu=1; break
    fi
  done
  if [ "$intel_gpu" -eq 0 ] && lsmod 2>/dev/null | grep -q '^i915'; then intel_gpu=1; fi
  if [ "$intel_gpu" -eq 0 ] && command -v lspci >/dev/null 2>&1; then
    if lspci -nn | grep -Eiq 'VGA|3D' && lspci -nn | grep -Eiq 'Intel.*(VGA|3D)'; then intel_gpu=1; fi
  fi
  local choice="${Drivers_Nvidia_CHOICE:-}"; local choice_up="${choice^^}"; local proprietary_nvidia=0
  case "$choice_up" in
    NVIDIA_DRIVERS) proprietary_nvidia=1 ;;
    NOUVEAU) proprietary_nvidia=0 ;;
    *)
        if [ -f /userdata/system/99-nvidia.conf ]; then
          proprietary_nvidia=1
        elif lsmod 2>/dev/null | grep -q '^nvidia'; then proprietary_nvidia=1; fi ;;
  esac
  {
    echo "boot-custom: Drivers_Nvidia_CHOICE='${choice}' (norm='${choice_up}')"
    echo "boot-custom: 99-nvidia.conf: $([ -f /userdata/system/99-nvidia.conf ] && echo present || echo absent)"
    echo "boot-custom: lsmod nvidia: $(lsmod 2>/dev/null | grep -q '^nvidia' && echo present || echo absent)"
    echo "boot-custom: proprietary_nvidia=${proprietary_nvidia}"; echo "boot-custom: intel_gpu=${intel_gpu}"
  } >> "$LOG_FILE"
  if [ "$proprietary_nvidia" -eq 1 ]; then
    echo "boot-custom: SKIP (NVIDIA proprietary detected)" >> "$LOG_FILE"
    hbox "Skipping ${BLUE}boot-custom.sh${NOCOLOR} install (NVIDIA proprietary driver)."; return 0
  fi
  if [ "$intel_gpu" -eq 1 ]; then
    echo "boot-custom: SKIP (Intel iGPU detected)" >> "$LOG_FILE"
    hbox "Skipping ${BLUE}boot-custom.sh${NOCOLOR} install (Intel iGPU)."; return 0
  fi
  local sel="${monitor_firmware:-}"
  case "$sel" in
    arcade_31|arcade_15_31|arcade_15_25_31|m2929|d9200|d9400|d9800|m3129| \
    pstar|ms2930|r666b|pc_31_120|pc_70_120|vesa_480|vesa_600|vesa_768|vesa_1024)
      echo "boot-custom: SKIP (profile=${sel})" >> "$LOG_FILE"
      hbox "Skipping ${BLUE}boot-custom.sh${NOCOLOR} (profile: ${sel})."
      return 0 ;;
  esac
  if [ ! -f "$SRC" ]; then
    echo "boot-custom: source not found: $SRC" >> "$LOG_FILE"; box_hash
    box_center "${YELLOW}boot-custom.sh not found at:${NOCOLOR}"; box_center "${BLUE}${SRC}${NOCOLOR}"; box_hash
    return 0
  fi
  if [ -f "$DST" ] && cmp -s "$SRC" "$DST"; then
    echo "boot-custom: already up-to-date at $DST" >> "$LOG_FILE"
    hbox "boot-custom.sh is already up-to-date in ${BLUE}/boot/${NOCOLOR}."; return 0
  fi
  echo "boot-custom: installing $SRC -> $DST" >> "$LOG_FILE"; mount -o remount,rw /boot 2>/dev/null || true
  if cp -f "$SRC" "$DST"; then
    chmod 0755 "$DST" 2>/dev/null || true; sync; echo "boot-custom: installed OK (0755) -> $DST" >> "$LOG_FILE"
    hbox "Installed ${GREEN}boot-custom.sh${NOCOLOR} to ${BLUE}/boot/${NOCOLOR} (0755)."
  else
    echo "boot-custom: COPY FAILED ($SRC -> $DST)" >> "$LOG_FILE"
    hbox "${RED}Failed to install boot-custom.sh to /boot${NOCOLOR}"
  fi
  mount -o remount,ro /boot 2>/dev/null || true; return 0
}
