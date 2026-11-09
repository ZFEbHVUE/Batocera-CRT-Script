EXTRA_DELETE_FILES=(
  "/userdata/system/99-nvidia.conf" "/userdata/system/batocera.conf.bak" "/userdata/system/batocera.conf"
  "/userdata/system/es.arg.override" "/userdata/system/videomodes.conf" "/userdata/system/videomodes.conf.bak"
  "/userdata/system/configs/multimedia_keys.conf" "/userdata/system/configs/emulationstation/es_systems_crt.cfg"
  "/userdata/system/configs/mame/mame.ini" "/userdata/system/configs/mame/mame.ini.bak"
  "/userdata/system/configs/mame/plugin.ini" "/userdata/system/configs/mame/ui.ini"
  "/userdata/system/configs/mame/ini/vertical.ini" "/boot/boot/overlay" "/boot/batocera-boot.conf.bak"
  "/boot/boot-custom.sh"
)
SYSLINUX_DIRS=(
  "/boot/boot" "/boot/boot/syslinux" "/boot/EFI" "/boot/EFI/batocera" "/boot/EFI/BOOT"
)
DIRS_TO_REMOVE=(
  "/userdata/system/scripts" "/userdata/system/configs/retroarch" "/userdata/roms/crt"
)
press_enter_to_reboot() { printf "\nPress ENTER to reboot "; read -r _; reboot; }
delete_if_exists() {
  local p="$1"
  if [ -e "$p" ] || [ -L "$p" ]; then
    rm -rf "$p"; msg "   Deleted: $p"
  fi
}
purge_syslinux_variants() {
  msg "==> Purging syslinux backup/initial variants where present…"
  for d in "${SYSLINUX_DIRS[@]}"; do
    [ -d "$d" ] || continue
    for name in "syslinux.cfg.bak" "syslinux.cfg.initial"; do
      local p="$d/$name"
      if [ -e "$p" ] || [ -L "$p" ]; then
        rm -f "$p"; msg "   Deleted: $p"
      fi
    done
  done
}
restore_file_from_backup() {
  local target="$1"; local backup_src="$BACKUP_ROOT$target"
  if [ -e "$backup_src" ]; then
    mkdir -p "$(dirname "$target")"; cp -a "$backup_src" "$target"; msg "   Restored: $target"; return 0
  else
    msg "   (missing in backup, skipped): $target"; return 1
  fi
}
# Wayland payload is /boot/boot. X11 payload is /boot/crt. Both linux files must be
# real separate copies, and a boot menu must name both.
wayland_and_x11_boot_present() {
  local f
  [ -f /boot/boot/linux ] && [ -f /boot/boot/initrd.gz ] && [ -f /boot/boot/batocera ] \
    && [ -f /boot/crt/linux ] && [ -f /boot/crt/batocera ] || return 1
  [ "$(stat -c %i /boot/boot/linux)" != "$(stat -c %i /boot/crt/linux)" ] || return 1
  for f in /boot/boot/syslinux.cfg /boot/boot/syslinux/syslinux.cfg \
           /boot/EFI/batocera/syslinux.cfg /boot/EFI/BOOT/grub.cfg; do
    [ -f "$f" ] || continue
    if grep -q '/boot/linux' "$f" && grep -q '/crt/linux' "$f"; then
      return 0
    fi
  done
  return 1
}
wayland_boot_fingerprint() {
  md5sum /boot/boot/linux /boot/boot/initrd.gz || return 1
  stat -c '%s %n' /boot/boot/batocera || return 1
  if [ -f /boot/boot/rufomaculata ]; then stat -c '%s %n' /boot/boot/rufomaculata || return 1; fi
  if [ -f /boot/batocera-boot.conf ]; then md5sum /boot/batocera-boot.conf || return 1; fi
  if [ -f /boot/EFI/BOOT/BOOTX64.EFI ]; then md5sum /boot/EFI/BOOT/BOOTX64.EFI || return 1; fi
}
boot_avail_kb() { df -Pk /boot | awk 'NR==2 {print $4}'; }
# Remove /boot/crt. If FAT keeps the clusters, recover the orphan chains and delete
# only the new FSCK*.REC files. Stop if a Wayland boot file changes.
reclaim_dualboot_boot_clusters() {
  local snap now dev fstype fsck rc before after crt_kb freed rec rec_before rec_after
  wayland_and_x11_boot_present || return 1
  snap=$(mktemp); now=$(mktemp); rec_before=$(mktemp); rec_after=$(mktemp)
  box_center "Checking the Wayland boot files before removing X11."
  if ! wayland_boot_fingerprint > "$snap"; then
    err_box "Could not read the Wayland boot files. X11 boot was left in place."
    rm -f "$snap" "$now" "$rec_before" "$rec_after"; return 1
  fi
  crt_kb=$(du -sk /boot/crt | awk '{print $1}')
  before=$(boot_avail_kb)
  remount_boot_rw
  rm -rf /boot/crt/
  sync
  box_center "/boot/crt/ removed"
  after=$(boot_avail_kb)
  if [ -n "$before" ] && [ -n "$after" ] && [ -n "$crt_kb" ]; then
    freed=$((after - before))
    if [ "$freed" -ge $((crt_kb * 9 / 10)) ]; then
      if ! wayland_boot_fingerprint > "$now" || ! cmp -s "$snap" "$now"; then
        err_box "Boot reclaim stopped: a Wayland boot file changed. Restore will not reboot."
        rm -f "$snap" "$now" "$rec_before" "$rec_after"; return 1
      fi
      box_center "Wayland boot files are unchanged. Boot space from the X11 tree was released."
      rm -f "$snap" "$now" "$rec_before" "$rec_after"; return 0
    fi
  fi
  box_center "X11 files are gone, but the boot partition did not free their space."
  dev=$(findmnt -n -o SOURCE /boot 2>/dev/null || awk '$2=="/boot" {print $1; exit}' /proc/mounts)
  fstype=$(findmnt -n -o FSTYPE /boot 2>/dev/null || awk '$2=="/boot" {print $3; exit}' /proc/mounts)
  case "$fstype" in
    vfat|msdos) ;;
    *)
      box_center "Boot reclaim skipped: /boot is ${fstype:-not a FAT filesystem}."
      rm -f "$snap" "$now" "$rec_before" "$rec_after"; return 0 ;;
  esac
  fsck=$(command -v dosfsck || command -v fsck.fat || command -v fsck.vfat || true)
  if [ -z "$fsck" ] || [ -z "$dev" ]; then
    box_center "Boot reclaim skipped: fsck.fat is not available."
    rm -f "$snap" "$now" "$rec_before" "$rec_after"; return 0
  fi
  find /boot -maxdepth 1 -name 'FSCK[0-9][0-9][0-9][0-9].REC' | sort > "$rec_before"
  mount -o remount,ro /boot 2>/dev/null || true
  box_center "Reclaiming orphaned X11 clusters on ${dev}."
  "$fsck" -a -w "$dev" >> "${CRT_LOG}" 2>&1
  rc=$?
  case "$rc" in
    0|1|2|3) ;;
    *)
      err_box "Boot reclaim stopped: fsck.fat exited ${rc}. Wayland files were not removed."
      mount -o remount,rw /boot 2>/dev/null || true
      rm -f "$snap" "$now" "$rec_before" "$rec_after"; return 1 ;;
  esac
  remount_boot_rw
  if ! wayland_boot_fingerprint > "$now"; then
    err_box "Boot reclaim stopped: the Wayland boot files could not be read after fsck."
    rm -f "$snap" "$now" "$rec_before" "$rec_after"; return 1
  fi
  if ! cmp -s "$snap" "$now"; then
    err_box "Boot reclaim stopped: a Wayland boot file changed. Restore will not reboot."
    rm -f "$snap" "$now" "$rec_before" "$rec_after"; return 1
  fi
  find /boot -maxdepth 1 -name 'FSCK[0-9][0-9][0-9][0-9].REC' | sort > "$rec_after"
  while IFS= read -r rec; do
    [ -n "$rec" ] || continue
    grep -Fxq "$rec" "$rec_before" && continue
    rm -f "$rec"
    msg "   Deleted recovered orphan: $rec"
  done < "$rec_after"
  sync
  box_center "Wayland boot files are unchanged. X11 boot space was released."
  rm -f "$snap" "$now" "$rec_before" "$rec_after"
  return 0
}
restore_all() {
  local LOG_FILE="${CRT_LOG}"; box_hash; box_center "${BOLD}Restore to stock Batocera${NOCOLOR}"; box_empty
  box_center "This will remove the script and restore system files from backup."
  box_center "Your ${GREEN}games and save files${NOCOLOR} will ${GREEN}NOT${NOCOLOR} be deleted."; box_hash
  if [ ! -d "$BACKUP_ROOT" ]; then
    box_hash; box_center "${RED}Backup folder not found:${NOCOLOR}"; box_center "${BLUE}${BACKUP_ROOT}${NOCOLOR}"
    box_empty; box_center "Aborting restore to avoid leaving the system in a bad state."; box_hash; return 1
  fi
  box_empty; box_center "Preparing boot partition for restore…"; box_empty; remount_boot_rw; box_empty
  box_center "Removing modified/managed files…"; box_empty
  for f in "${FILES_TO_HANDLE[@]}"; do delete_if_exists "$f"; done
  for f in "${EXTRA_DELETE_FILES[@]}"; do delete_if_exists "$f"; done
  box_empty; box_center "Purging syslinux.cfg variants…"; box_empty; purge_syslinux_variants; box_empty
  box_center "Removing folders…"; box_empty
  for d in "${DIRS_TO_REMOVE[@]}"; do delete_if_exists "$d"; done
  box_empty; box_center "Restoring files from backup…"; box_empty
  for f in "${FILES_TO_HANDLE[@]}"; do restore_file_from_backup "$f"; done
  box_empty; box_center "Cleaning up mode switcher flags…"; box_empty
  local mode_switcher_flag="${CRTD}/Geometry_modeline/.mode_switcher_first_run"
  if [ -f "$mode_switcher_flag" ]; then
    rm -f "$mode_switcher_flag"; box_center "Mode switcher first-run flag removed"
  fi
  if [ -d "$BASE_DIR/mode_backups" ]; then
    rm -rf "$BASE_DIR/mode_backups"; box_center "HD/CRT mode backups removed"
  fi
  if [ -d /boot/crt ]; then
    box_empty
    if wayland_and_x11_boot_present; then
      box_center "Wayland and X11 are both installed. The X11 boot will be removed and its space released."
      box_empty
      reclaim_dualboot_boot_clusters || return 1
    else
      box_center "Removing /boot/crt/ without a boot-space reclaim."
      box_empty; remount_boot_rw; rm -rf /boot/crt/
      box_center "/boot/crt/ removed"
    fi
    if [ -f /boot/boot/overlay ]; then
      rm -f /boot/boot/overlay; box_center "/boot/boot/overlay removed (factory Wayland restored)"
    fi
    if [ -f /boot/boot-custom.sh ]; then
      rm -f /boot/boot-custom.sh; box_center "/boot/boot-custom.sh removed"
    fi
    local f
    for f in /boot/EFI/batocera/syslinux.cfg \
             /boot/boot/syslinux.cfg \
             /boot/boot/syslinux/syslinux.cfg; do
      if [ -f "$f" ] && grep -q '^LABEL crt' "$f"; then
        sed -i '/^LABEL crt$/,/^$/d' "$f"; sed -i '/^DEFAULT crt$/d' "$f"
        if ! grep -q 'MENU DEFAULT' "$f"; then sed -i '/^LABEL batocera$/a\	MENU DEFAULT' "$f"; fi
        sed -i 's/Batocera HD - Wayland (\^normal)/Batocera.linux (^normal)/' "$f"
        sed -i 's/Batocera HD - Wayland (\^verbose)/Batocera.linux (^verbose)/' "$f"
        box_center "$(basename "$(dirname "$f")")/syslinux.cfg restored"
      fi
    done
    if [ -d /sys/firmware/efi ]; then
      local grub_cfg="/boot/EFI/BOOT/grub.cfg"
      if [ -f "$grub_cfg" ]; then
        sed -i '/menuentry "Batocera CRT (X11)"/,/^}/d' "$grub_cfg"
        sed -i 's/menuentry "Batocera HD (Wayland)"/menuentry "Batocera.linux (normal)"/' "$grub_cfg"
        sed -i 's/menuentry "Batocera HD (verbose)"/menuentry "Batocera.linux (verbose)"/' "$grub_cfg"
        sed -i 's/set default="1"/set default="0"/' "$grub_cfg"; sed -i 's/set timeout="3"/set timeout="1"/' "$grub_cfg"
        box_center "grub.cfg fallback restored"
      fi
    fi
    mount -o remount,ro /boot 2>/dev/null
    rm -f "${CRT_SCRIPT_DIR:-/userdata/system/Batocera-CRT-Script}/batocera-save-crt-overlay"
    rm -f "${PHASE_FLAG:-/userdata/system/Batocera-CRT-Script/.install_phase}"; box_center "Dual-boot cleanup complete"
  fi
  hbox "${GREEN}Restore complete.${NOCOLOR} A reboot is required."; press_enter_to_reboot
}
