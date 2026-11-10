# Batocera-CRT-Script v44 - step 23: install review
REVIEW_CHOICE=""
read_review_choice() {
  local choice=""
  while :; do
    box_empty
    box_center "1  Confirm and save"
    box_center "2  ${1}"
    box_center "3  Cancel"
    box_empty
    if [ -e /dev/tty ]; then
      IFS= read -r choice </dev/tty || choice=""
    else IFS= read -r choice || choice=""; fi
    case "$choice" in
      1|2|3) REVIEW_CHOICE="$choice"; return 0 ;;
      *) box_center "Enter 1, 2, or 3." ;;
    esac
  done
}
review_crt_plan() {
  hbox "Review the CRT install"
  box_empty
  box_center "Card: ${selected_card:-unknown}  (${TYPE_OF_CARD:-unknown})"
  if [ -n "${Drivers_Nvidia_CHOICE:-}" ] && [ "${Drivers_Nvidia_CHOICE}" != "NONE" ]; then
    box_center "Driver: ${Drivers_Nvidia_CHOICE} ${Drivers_Name_Nvidia_CHOICE:-}"
  fi
  local usb_poll="Default"
  if [ "${polling_rate:-}" = "usbhid.jspoll=1 xpad.cpoll=1" ]; then
    usb_poll="On"
  fi
  box_center "Output: ${video_output:-unset}"
  box_center "Monitor Profile: ${monitor_firmware:-unset}"
  box_center "Boot Resolution: ${EDID_resolution:-unset}"
  box_center "Rotation: ${Rotating_screen:-unset}"
  box_center "ES Orientation: ${ES_rotation:-unset}"
  box_center "Advanced: ${DT_SR_Choice:-NO}"
  if [ "${DT_SR_Choice:-NO}" = "YES" ]; then
    box_center "Dotclock: ${dotclock_min:-unset}"
    box_center "Super-res: ${super_width:-unset}"
  fi
  box_center "USB Fast Polling: ${usb_poll}"
  box_empty
  if [ "${IS_PHASE2:-false}" = true ]; then
    box_center "Confirming writes the boot entry, system files, and CRT overlay."
    box_center "The machine then shuts down. Power it on to boot CRT mode."
  else
    box_center "Confirming writes the boot entry, system files, and overlay."
    box_center "The machine then reboots into CRT mode."
  fi
  box_center "Cancel leaves the boot partition unchanged."
  box_hash
  read_review_choice "Change answers"
}
discard_unconfirmed_install_files() {
  if [ "${CRT_WROTE_10_MONITOR:-0}" = 1 ]; then
    rm -f /etc/X11/xorg.conf.d/10-monitor.conf
    CRT_WROTE_10_MONITOR=0
  fi
  if [ "${CRT_SWITCHRES_BAK_NEW:-0}" = 1 ] && [ -f /etc/switchres.ini.bak ]; then
    cp -f /etc/switchres.ini.bak /etc/switchres.ini
    rm -f /etc/switchres.ini.bak
    CRT_SWITCHRES_BAK_NEW=0
  fi
  if [ -n "${Name_monitor_EDID:-}" ]; then
    rm -f "/lib/firmware/edid/${Name_monitor_EDID}"
  fi
}
install_selected_videomodes() {
  local src=""
  if [ "${Amd_NvidiaND_IntelDP:-0}" = "1" ]; then
    src="${CRTD}/System_configs/VideoModes/Amd_NvidiaND_IntelDP/${Name_VideoModes:-}"
  elif [ "${Intel_Nvidia_NOUV:-0}" = "1" ]; then
    src="${CRTD}/System_configs/VideoModes/Intel_NvidiaNOUV/${Name_VideoModes:-}"
  else
    err_box "No videomodes set for this card."
    return 1
  fi
  if [ ! -f "$src" ]; then
    err_box "Missing videomodes file: ${src}"
    return 1
  fi
  cp "$src" /userdata/system/videomodes.conf
  chmod 644 /userdata/system/videomodes.conf
  cp /userdata/system/videomodes.conf /userdata/system/videomodes.conf.bak
}
