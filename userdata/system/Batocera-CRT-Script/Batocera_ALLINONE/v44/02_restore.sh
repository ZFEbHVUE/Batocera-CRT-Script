
# v42 Backup & Restore Helper
# - First run: creates BACKUP/ with original files and writes backup.file
# - Subsequent runs: offers to (1) continue install or (2) restore to stock (removes script + restores files)

set -u
: "${PARSED_ENGINE:=}"
: "${PARSED_VERSION:=}"
: "${PCI_ADDR:=}"
: "${CARD_INDEX:=}"


# --- Paths ---
BASE_DIR="/userdata/Batocera-CRT-Script-Backup"
CHECK_FILE="$BASE_DIR/backup.file"
BACKUP_ROOT="$BASE_DIR/BACKUP"

# Ensure backup dirs exist and migrate any legacy backup flag
LEGACY_DIR="/userdata/system/Batocera-CRT-Script"
LEGACY_FILE="$LEGACY_DIR/backup.file"

mkdir -p "$BASE_DIR" "$BACKUP_ROOT"

# If old flag exists and new one doesn't, migrate it
if [ -f "$LEGACY_FILE" ] && [ ! -f "$CHECK_FILE" ]; then
  mv -f "$LEGACY_FILE" "$CHECK_FILE"
  echo "Migrated legacy backup flag to $CHECK_FILE" >> "$LOG_FILE"
fi

# Files to backup/restore (absolute)
FILES_TO_HANDLE=(
  "/boot/batocera-boot.conf"
  "/boot/boot/syslinux.cfg"
  "/boot/boot/syslinux/syslinux.cfg"
  "/boot/EFI/syslinux.cfg"
  "/boot/EFI/batocera/syslinux.cfg"
  "/boot/EFI/BOOT/syslinux.cfg"
  "/userdata/system/batocera.conf"
)

# Extra files to delete on restore (if present)
EXTRA_DELETE_FILES=(
  "/userdata/system/99-nvidia.conf"
  "/userdata/system/batocera.conf.bak"
  "/userdata/system/batocera.conf"
  "/userdata/system/es.arg.override"
  "/userdata/system/videomodes.conf"
  "/userdata/system/videomodes.conf.bak"
  "/userdata/system/configs/multimedia_keys.conf"
  "/userdata/system/configs/emulationstation/es_systems_crt.cfg"
  "/userdata/system/configs/mame/mame.ini"
  "/userdata/system/configs/mame/mame.ini.bak"
  "/userdata/system/configs/mame/plugin.ini"
  "/userdata/system/configs/mame/ui.ini"
  "/userdata/system/configs/mame/ini/vertical.ini"
  "/boot/boot/overlay"
  "/boot/batocera-boot.conf.bak"
  "/boot/boot-custom.sh"
)

# Directories whose syslinux.cfg.bak / syslinux.cfg.initial should be purged if present
SYSLINUX_DIRS=(
  "/boot/boot"
  "/boot/boot/syslinux"
  "/boot/EFI"
  "/boot/EFI/batocera"
  "/boot/EFI/BOOT"
)

# Folders to remove entirely on restore
DIRS_TO_REMOVE=(
  "/userdata/system/scripts"
  "/userdata/system/configs/retroarch"
  "/userdata/roms/crt"
)

# --- Helpers ---

msg() { printf "%s\n" "$*"; }
press_enter() { printf "\nPress ENTER to continue "; read -r _; }
press_enter_to_reboot() { printf "\nPress ENTER to reboot "; read -r _; reboot; }

make_parent_and_copy_preserve() {
  # $1 = source absolute, $2 = destination absolute
  local src="$1" dst="$2" dstdir
  dstdir="$(dirname "$dst")"
  mkdir -p "$dstdir"
  if [ -e "$src" ]; then
    # Preserve attributes (-a). BusyBox cp supports -a on Batocera.
    cp -a "$src" "$dst"
    return 0
  else
    return 1
  fi
}

# Record the live HD monitor for Wayland and X11.
# Called when the system-restore backup is created, before any driver reboot
# and before videomodes.conf replaces listModes with 15 kHz modelines.
# A later pass skips this when hd_mode_list.txt already has content.
capture_hd_monitor_list() {
  local dest="/userdata/Batocera-CRT-Script-Backup/mode_backups/hd_mode/video_settings"
  mkdir -p "$dest"

  # X11 batocera-resolution talks to the X server. A Wayland session does not.
  if [ -z "$(ls /run/user/*/wayland-* 2>/dev/null)" ] && ! pgrep -x labwc >/dev/null 2>&1; then
    export DISPLAY="${DISPLAY:-:0}"
    if [ -z "${XAUTHORITY:-}" ] && [ -f /var/lib/.Xauthority ]; then
      export XAUTHORITY=/var/lib/.Xauthority
    fi
  fi

  if [ -z "${WAYLAND_DISPLAY:-}" ]; then
    if [ -S /run/wayland-0 ] || ls /run/user/*/wayland-0 >/dev/null 2>&1; then
      export WAYLAND_DISPLAY=wayland-0
      export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run}"
    fi
  fi

  local stack="wayland"
  if command -v batocera-resolution >/dev/null 2>&1; then
    local detected
    detected=$(batocera-resolution getDisplayMode 2>/dev/null || true)
    [ "$detected" = "xorg" ] && stack="xorg"
  fi

  # The primary output can be the CRT DAC, which only advertises 640x480.
  # Use the connected output whose real modes go above that.
  local screen="" out line id res w h px top best_px
  best_px=0
  while IFS= read -r out; do
    [ -z "$out" ] && continue
    top=0
    while IFS= read -r line; do
      id="${line%%:*}"
      case "$id" in max-*|"") continue ;; esac
      res="${id%%.*}"
      w="${res%%x*}"
      h="${res#*x}"
      case "$w" in *[!0-9]*) continue ;; esac
      case "$h" in *[!0-9]*) continue ;; esac
      px=$((w * h))
      [ "$px" -gt "$top" ] && top=$px
    done <<EOF
$(batocera-resolution --screen "$out" listModes 2>/dev/null)
EOF
    if [ "$top" -gt "$best_px" ]; then
      best_px=$top
      screen=$out
    fi
  done <<EOF
$(batocera-resolution listOutputs 2>/dev/null)
EOF

  local tmp
  tmp=$(mktemp)
  if [ -n "$screen" ]; then
    batocera-resolution --screen "$screen" listModes > "$tmp" 2>/dev/null || true
  else
    batocera-resolution listModes > "$tmp" 2>/dev/null || true
  fi
  if [ ! -s "$tmp" ]; then
    rm -f "$tmp"
    box_center "Could not read the HD monitor mode list."
    return 0
  fi

  {
    echo "STACK=$stack"
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      local id="${line%%:*}"
      [ "$id" = "max-640x480" ] && continue
      printf '%s\n' "$line"
    done < "$tmp"
  } > "${dest}/hd_mode_list.txt"
  echo "$stack" > "${dest}/hd_display_stack.txt"
  local _mon=""
  if [ -n "$screen" ] && command -v wlr-randr >/dev/null 2>&1; then
    _mon=$(XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run}" WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}" wlr-randr 2>/dev/null \
      | awk -v screen="$screen" '
          $1 == screen { grab=1; next }
          grab && $0 !~ /^[[:space:]]/ { exit }
          grab && index($0, "Model:") { sub(/.*Model: /, ""); print; exit }
        ')
  fi
  if [ -z "$_mon" ] && command -v wlr-randr >/dev/null 2>&1; then
    _mon=$(XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run}" WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}" wlr-randr 2>/dev/null \
      | awk -F'Model: ' '/Model:/ { print $2; exit }')
  fi
  # X11 has no wlr-randr. The product name is in the EDID of the chosen screen.
  if [ -z "$_mon" ] && [ -n "$screen" ] && command -v edid-decode >/dev/null 2>&1; then
    local _drm _d _cand
    _drm="$screen"
    case "$screen" in
      HDMI-[0-9]*) _drm="HDMI-A-${screen#HDMI-}" ;;
    esac
    for _cand in "$_drm" "$screen"; do
      for _d in /sys/class/drm/card*-"$_cand"; do
        [ -r "$_d/edid" ] || continue
        _mon=$(edid-decode "$_d/edid" 2>/dev/null | sed -n "s/.*Display Product Name: '\\([^']*\\)'.*/\\1/p" | head -1)
        [ -n "$_mon" ] && break 2
      done
    done
    if [ -z "$_mon" ]; then
      case "$screen" in
        HDMI-[0-9]*)
          for _d in /sys/class/drm/card*-HDMI-B-"${screen#HDMI-}"; do
            [ -r "$_d/edid" ] || continue
            _mon=$(edid-decode "$_d/edid" 2>/dev/null | sed -n "s/.*Display Product Name: '\\([^']*\\)'.*/\\1/p" | head -1)
            [ -n "$_mon" ] && break
          done
          ;;
      esac
    fi
  fi
  if [ -n "$_mon" ]; then
    printf '%s\n' "$_mon" > "${dest}/hd_monitor.txt"
    box_center "HD monitor: ${_mon}"
  fi
  rm -f "$tmp"

  local current res chosen best_delta line id label hz milli delta
  if [ -n "$screen" ]; then
    current=$(batocera-resolution --screen "$screen" currentMode 2>/dev/null || true)
  else
    current=$(batocera-resolution currentMode 2>/dev/null || true)
  fi
  case "$current" in
    unknown*|""|640x480.*) current="" ;;
  esac
  res="${current%%.*}"
  chosen=""
  best_delta=999999
  # A cap like max-3440x1440 does not change refresh. This panel's preferred
  # mode can be 165Hz, which leaves EmulationStation black. Keep the full list,
  # and preselect the ~60Hz mode at the resolution that is on screen.
  while IFS= read -r line; do
    [[ "$line" == STACK=* ]] && continue
    id="${line%%:*}"
    label="${line#*:}"
    [[ "$id" == max-* ]] && continue
    [[ "$id" != "${res}."* ]] && continue
    hz=$(echo "$label" | awk '{print $(NF-1)}')
    milli=$(echo "$hz" | awk '{printf "%d", ($1 * 1000) + 0.5}')
    [ -z "$milli" ] && continue
    if [ "$milli" -gt 60000 ]; then
      delta=$((milli - 60000))
    else
      delta=$((60000 - milli))
    fi
    if [ "$delta" -lt "$best_delta" ]; then
      best_delta=$delta
      chosen=$id
    fi
  done < "${dest}/hd_mode_list.txt"

  if [ -z "$chosen" ]; then
    local best_px=0 px
    best_delta=999999
    while IFS= read -r line; do
      [[ "$line" == STACK=* ]] && continue
      id="${line%%:*}"
      label="${line#*:}"
      [[ "$id" == max-* ]] && continue
      res="${id%%.*}"
      w="${res%%x*}"
      h="${res#*x}"
      case "$w" in *[!0-9]*) continue ;; esac
      case "$h" in *[!0-9]*) continue ;; esac
      px=$((w * h))
      [ "$px" -lt "$best_px" ] && continue
      hz=$(echo "$label" | awk '{print $(NF-1)}')
      milli=$(echo "$hz" | awk '{printf "%d", ($1 * 1000) + 0.5}')
      [ -z "$milli" ] && continue
      if [ "$milli" -gt 60000 ]; then
        delta=$((milli - 60000))
      else
        delta=$((60000 - milli))
      fi
      if [ "$px" -gt "$best_px" ] || [ "$delta" -lt "$best_delta" ]; then
        best_px=$px
        best_delta=$delta
        chosen=$id
      fi
    done < "${dest}/hd_mode_list.txt"
  fi

  if [ -n "$chosen" ]; then
    echo "global.videomode=$chosen" > "${dest}/video_mode.txt"
    echo "es.resolution=$chosen" > "${dest}/es_resolution.txt"
    box_center "Saved HD monitor list. Preselected ${chosen}."
  else
    box_center "Saved HD monitor list."
  fi
}

backup_once() {
  msg "==> Preparing first-run BACKUP…"
  mkdir -p "$BACKUP_ROOT"

  local ok_count=0 miss_count=0
  for f in "${FILES_TO_HANDLE[@]}"; do
    local dst="$BACKUP_ROOT$f"
    if make_parent_and_copy_preserve "$f" "$dst"; then
      msg "   Backed up: $f -> $dst"
      ok_count=$((ok_count+1))
    else
      msg "   (missing, skipped): $f"
      miss_count=$((miss_count+1))
    fi
  done

  # Write check file regardless (we only run this once)
  mkdir -p "$BASE_DIR"
  date +"%Y-%m-%d %H:%M:%S" > "$CHECK_FILE"

  # HD monitor list, before a Sea Islands reboot or the 15 kHz mode file.
  if [ ! -s /userdata/Batocera-CRT-Script-Backup/mode_backups/hd_mode/video_settings/hd_mode_list.txt ]; then
    capture_hd_monitor_list
  fi

  # Baseline system-restore backup summary (nice UI)
  box_hash
  box_center "System restore backup created"
  box_empty
  box_center "A baseline backup of your Batocera system files was made"
  box_center "before any script changes. You can use it later to return to"
  box_center "a clean/default Batocera installation."
  box_empty
  box_center "Your games and save files are not touched."
  box_empty
  box_center "Captured files: ${GREEN}${ok_count}${NOCOLOR}   Missing/skipped: ${YELLOW}${miss_count}${NOCOLOR}"
  box_center "Restore checkpoint: ${BLUE}${CHECK_FILE}${NOCOLOR}"
  box_hash

  prompt_centered_tty "Press ${BLUE}ENTER${NOCOLOR} to continue…"
}
remount_boot_rw() {
  # Make /boot writable for restore
  msg "==> Remounting /boot as read-write…"
  mount -o remount,rw /boot 2>/dev/null || true
}

delete_if_exists() {
  # $1 = path
  local p="$1"
  if [ -e "$p" ] || [ -L "$p" ]; then
    rm -rf "$p"
    msg "   Deleted: $p"
  fi
}

purge_syslinux_variants() {
  # Remove syslinux.cfg.bak and syslinux.cfg.initial in known dirs
  msg "==> Purging syslinux backup/initial variants where present…"
  for d in "${SYSLINUX_DIRS[@]}"; do
    [ -d "$d" ] || continue
    for name in "syslinux.cfg.bak" "syslinux.cfg.initial"; do
      local p="$d/$name"
      if [ -e "$p" ] || [ -L "$p" ]; then
        rm -f "$p"
        msg "   Deleted: $p"
      fi
    done
  done
}

restore_file_from_backup() {
  # Restores a single absolute file path from BACKUP_ROOT mirror, preserving attrs
  # $1 = absolute path to restore
  local target="$1"
  local backup_src="$BACKUP_ROOT$target"
  if [ -e "$backup_src" ]; then
    mkdir -p "$(dirname "$target")"
    cp -a "$backup_src" "$target"
    msg "   Restored: $target"
    return 0
  else
    msg "   (missing in backup, skipped): $target"
    return 1
  fi
}
########################################################################################
#####################                 RESTORE START                         #################
########################################################################################
restore_all() {
  # Use the same log file as the rest of the script (already defined globally)
  local LOG_FILE="/userdata/system/logs/BUILD_15KHz_Batocera.log"

  # ---------- Header ----------
  box_hash
  box_center "${BOLD}Restore to stock Batocera${NOCOLOR}"
  box_empty
  box_center "This will remove the script and restore system files from backup."
  box_center "Your ${GREEN}games and save files${NOCOLOR} will ${GREEN}NOT${NOCOLOR} be deleted."
  box_hash

  # Safety: ensure we actually have a backup to restore from
  if [ ! -d "$BACKUP_ROOT" ]; then
    box_hash
    box_center "${RED}Backup folder not found:${NOCOLOR}"
    box_center "${BLUE}${BACKUP_ROOT}${NOCOLOR}"
    box_empty
    box_center "Aborting restore to avoid leaving the system in a bad state."
    box_hash
    return 1
  fi

  # Remount /boot RW
  box_empty
  box_center "Preparing boot partition for restore…"
  box_empty
  remount_boot_rw

  # Delete managed files
  box_empty
  box_center "Removing modified/managed files…"
  box_empty
  for f in "${FILES_TO_HANDLE[@]}"; do delete_if_exists "$f"; done
  for f in "${EXTRA_DELETE_FILES[@]}"; do delete_if_exists "$f"; done

  # Purge syslinux variants
  box_empty
  box_center "Purging syslinux.cfg variants…"
  box_empty
  purge_syslinux_variants

  # Remove folders
  box_empty
  box_center "Removing folders…"
  box_empty
  for d in "${DIRS_TO_REMOVE[@]}"; do delete_if_exists "$d"; done

  # Restore from backup mirror (preserve attrs via cp -a)
  box_empty
  box_center "Restoring files from backup…"
  box_empty
  for f in "${FILES_TO_HANDLE[@]}"; do restore_file_from_backup "$f"; done

  # Remove mode switcher first-run flag so warning shows again after restore
  box_empty
  box_center "Cleaning up mode switcher flags…"
  box_empty
  local mode_switcher_flag="/userdata/system/Batocera-CRT-Script/Geometry_modeline/.mode_switcher_first_run"
  if [ -f "$mode_switcher_flag" ]; then
    rm -f "$mode_switcher_flag"
    box_center "Mode switcher first-run flag removed"
  fi

  # The HD list is captured once and then skipped. A stock restore must drop
  # it, or the next install keeps the old monitor instead of reading the one
  # that is connected now. This is mode_backups only. BACKUP/ stays.
  if [ -d "$BASE_DIR/mode_backups" ]; then
    rm -rf "$BASE_DIR/mode_backups"
    box_center "HD/CRT mode backups removed"
  fi

  # Dual-boot cleanup: remove CRT boot environment if it was installed
  if [ -d /boot/crt ]; then
    box_empty
    box_center "Removing dual-boot CRT environment…"
    box_empty

    remount_boot_rw

    # Remove CRT boot files
    rm -rf /boot/crt/
    box_center "/boot/crt/ removed"

    # Remove Wayland overlay — it was contaminated by batocera-save-overlay
    # writing CRT-specific binaries (patched batocera-resolution, etc.) into
    # /boot/boot/overlay.  Deleting it restores factory Wayland squashfs state.
    if [ -f /boot/boot/overlay ]; then
      rm -f /boot/boot/overlay
      box_center "/boot/boot/overlay removed (factory Wayland restored)"
    fi

    # Remove boot-custom.sh from /boot
    if [ -f /boot/boot-custom.sh ]; then
      rm -f /boot/boot-custom.sh
      box_center "/boot/boot-custom.sh removed"
    fi

    # Restore all syslinux.cfg files to single-boot state
    local f
    for f in /boot/EFI/batocera/syslinux.cfg \
             /boot/boot/syslinux.cfg \
             /boot/boot/syslinux/syslinux.cfg; do
      if [ -f "$f" ] && grep -q '^LABEL crt' "$f"; then
        # Remove CRT label block (from LABEL crt to next blank line or EOF)
        sed -i '/^LABEL crt$/,/^$/d' "$f"
        # Remove any DEFAULT crt directive
        sed -i '/^DEFAULT crt$/d' "$f"
        # Restore MENU DEFAULT to the batocera entry
        if ! grep -q 'MENU DEFAULT' "$f"; then
          sed -i '/^LABEL batocera$/a\	MENU DEFAULT' "$f"
        fi
        # Restore original label names
        sed -i 's/Batocera HD - Wayland (\^normal)/Batocera.linux (^normal)/' "$f"
        sed -i 's/Batocera HD - Wayland (\^verbose)/Batocera.linux (^verbose)/' "$f"
        box_center "$(basename "$(dirname "$f")")/syslinux.cfg restored"
      fi
    done

    # Restore grub.cfg fallback to single-boot state
    if [ -d /sys/firmware/efi ]; then
      local grub_cfg="/boot/EFI/BOOT/grub.cfg"
      if [ -f "$grub_cfg" ]; then
        sed -i '/menuentry "Batocera CRT (X11)"/,/^}/d' "$grub_cfg"
        sed -i 's/menuentry "Batocera HD (Wayland)"/menuentry "Batocera.linux (normal)"/' "$grub_cfg"
        sed -i 's/menuentry "Batocera HD (verbose)"/menuentry "Batocera.linux (verbose)"/' "$grub_cfg"
        sed -i 's/set default="1"/set default="0"/' "$grub_cfg"
        sed -i 's/set timeout="3"/set timeout="1"/' "$grub_cfg"
        box_center "grub.cfg fallback restored"
      fi
    fi

    mount -o remount,ro /boot 2>/dev/null

    # Remove CRT overlay save script
    rm -f "${CRT_SCRIPT_DIR:-/userdata/system/Batocera-CRT-Script}/batocera-save-crt-overlay"

    # Remove phase flag if lingering
    rm -f "${PHASE_FLAG:-/userdata/system/Batocera-CRT-Script/.install_phase}"

    box_center "Dual-boot cleanup complete"
  fi

  # Footer
  box_hash
  box_center "${GREEN}Restore complete.${NOCOLOR} A reboot is required."
  box_hash

  # Prompt to reboot (existing helper)
  press_enter_to_reboot
}
########################################################################################
#####################                 RESTORE END                           #################
########################################################################################

########################################################################################
#####################                 BACKUP EXIST START			   #################
########################################################################################
prompt_when_backup_exists() {
  local LOG_FILE="/userdata/system/logs/BUILD_15KHz_Batocera.log"

  # ---------- Banner ----------
  box_hash
  box_center "${BOLD}A backup was found${NOCOLOR}"
  box_empty
  box_center "Run the installer again (Press Enter or 1)"
  box_center "Restore to stock Batocera (Remove the Script, Press 2)"
  box_empty
  box_center "Your games and save files will ${GREEN}NOT${NOCOLOR} be deleted."
  box_hash

  # ---------- Choice loop (read from /dev/tty if available) ----------
  local choice=""
  while :; do
    box_empty
    box_center "Your choice (1) Enter or (2) Restore [1/2]:"
    box_empty

    if [ -e /dev/tty ]; then
      IFS= read -r choice </dev/tty || choice=""
    else
      IFS= read -r choice || choice=""
    fi

    printf "backup menu choice: %s\n" "${choice}" >> "$LOG_FILE"
    choice="${choice:-1}"

    case "$choice" in
      1)
        box_center "Proceeding with installation/setup…"
        printf "Proceeding with installation/setup…\n" >> "$LOG_FILE"
        BACKUP_CHOICE="1"
        printf "\n"
        return 0
        ;;
      2)
        box_center "Restoring stock Batocera (removing the Script)…"
        printf "Restoring stock Batocera (removing the Script)…\n" >> "$LOG_FILE"
        restore_all
        # If restore_all returns, it failed or was cancelled—abort to be safe.
        exit 1
        ;;
      *)
        box_empty
        box_center "Please press 1 (or ENTER) to continue, or 2 to restore."
        box_empty
        ;;
    esac
  done
}



backup_restore_main() {
  # Ensure base paths exist
  mkdir -p "$BASE_DIR"

  if [ ! -f "$CHECK_FILE" ]; then
    backup_once
    # Return to caller (installer) after ENTER
    return 0
  else
    prompt_when_backup_exists
    return 0
  fi
}

# Read Batocera version (fallback to "unknown" if the command is missing)
version_Batocera="$(batocera-es-swissknife --version 2>/dev/null || echo unknown)"
echo "Version batocera = ${version_Batocera}" >> /userdata/system/logs/BUILD_15KHz_Batocera.log

case "${version_Batocera}" in
  44*)
    echo "Version 44"
    Version_of_batocera="v44"
    VERSION_BATOCERA_NUM=44
    ;;
  *)
    echo "Unknown or unsupported Batocera version: ${version_Batocera}"
    Version_of_batocera="unknown"
    VERSION_BATOCERA_NUM=0
    ;;
esac

if [ "$Version_of_batocera" != "v44" ]; then
  box_hash
  box_center "${RED}WRONG BATOCERA VERSION${NOCOLOR}"
  box_center "This script requires Batocera v44."
  box_center "Detected: ${version_Batocera}"
  box_center "Please use the correct script for your version."
  box_hash
  exit 1
fi

# (Optional) temporary compatibility for any stray references to the old misspelled var.
# You can remove this after you’re sure nothing reads "version".
version="${VERSION_BATOCERA_NUM}"

