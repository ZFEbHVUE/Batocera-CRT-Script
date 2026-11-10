# Batocera-CRT-Script v44 - step 04: backup
# First-run system backup (BACKUP/ + backup.file), HD monitor mode capture for the HD/CRT mode switcher,
# and the "backup found" menu (backup_restore_main). Restore lives in step 25.
BASE_DIR="/userdata/Batocera-CRT-Script-Backup"; CHECK_FILE="$BASE_DIR/backup.file"; BACKUP_ROOT="$BASE_DIR/BACKUP"
LEGACY_DIR="${CRTD}"; LEGACY_FILE="$LEGACY_DIR/backup.file"; mkdir -p "$BASE_DIR" "$BACKUP_ROOT"
if [ -f "$LEGACY_FILE" ] && [ ! -f "$CHECK_FILE" ]; then
  mv -f "$LEGACY_FILE" "$CHECK_FILE"; echo "Migrated legacy backup flag to $CHECK_FILE" >> "$LOG_FILE"
fi
FILES_TO_HANDLE=(
  "/boot/batocera-boot.conf" "/boot/boot/syslinux.cfg" "/boot/boot/syslinux/syslinux.cfg" "/boot/EFI/syslinux.cfg"
  "/boot/EFI/batocera/syslinux.cfg" "/boot/EFI/BOOT/syslinux.cfg" "/userdata/system/batocera.conf"
)
msg() { printf "%s\n" "$*"; }
make_parent_and_copy_preserve() {
  local src="$1" dst="$2" dstdir; dstdir="$(dirname "$dst")"; mkdir -p "$dstdir"
  if [ -e "$src" ]; then
    cp -a "$src" "$dst"; return 0
  else return 1; fi
}
capture_hd_monitor_list() {
  local dest="/userdata/Batocera-CRT-Script-Backup/mode_backups/hd_mode/video_settings"; mkdir -p "$dest"
  if [ -z "$(ls /run/user/*/wayland-* 2>/dev/null)" ] && ! pgrep -x labwc >/dev/null 2>&1; then
    export DISPLAY="${DISPLAY:-:0}"
    if [ -z "${XAUTHORITY:-}" ] && [ -f /var/lib/.Xauthority ]; then export XAUTHORITY=/var/lib/.Xauthority; fi
  fi
  if [ -z "${WAYLAND_DISPLAY:-}" ]; then
    if [ -S /run/wayland-0 ] || ls /run/user/*/wayland-0 >/dev/null 2>&1; then
      export WAYLAND_DISPLAY=wayland-0; export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run}"
    fi
  fi
  local stack="wayland"
  if command -v batocera-resolution >/dev/null 2>&1; then
    local detected
    detected=$(batocera-resolution getDisplayMode 2>/dev/null || true)
    [ "$detected" = "xorg" ] && stack="xorg"
  fi
  local screen="" out line id res w h px top best_px; best_px=0
  while IFS= read -r out; do
    [ -z "$out" ] && continue; top=0
    while IFS= read -r line; do
      id="${line%%:*}"
      case "$id" in max-*|"") continue ;; esac
      res="${id%%.*}"; w="${res%%x*}"; h="${res#*x}"
      case "$w" in *[!0-9]*) continue ;; esac
      case "$h" in *[!0-9]*) continue ;; esac
      px=$((w * h))
      [ "$px" -gt "$top" ] && top=$px
    done <<EOF
$(batocera-resolution --screen "$out" listModes 2>/dev/null)
EOF
    if [ "$top" -gt "$best_px" ]; then
      best_px=$top; screen=$out
    fi
  done <<EOF
$(batocera-resolution listOutputs 2>/dev/null)
EOF
  local tmp
  tmp=$(mktemp)
  if [ -n "$screen" ]; then
    batocera-resolution --screen "$screen" listModes > "$tmp" 2>/dev/null || true
  else batocera-resolution listModes > "$tmp" 2>/dev/null || true; fi
  if [ ! -s "$tmp" ]; then
    rm -f "$tmp"; box_center "Could not read the HD monitor mode list."; return 0
  fi
  {
    echo "STACK=$stack"
    while IFS= read -r line; do
      [ -z "$line" ] && continue; local id="${line%%:*}"; [ "$id" = "max-640x480" ] && continue; printf '%s\n' "$line"
    done < "$tmp"
  } > "${dest}/hd_mode_list.txt"
  echo "$stack" > "${dest}/hd_display_stack.txt"; local _mon=""
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
  if [ -z "$_mon" ] && [ -n "$screen" ] && command -v edid-decode >/dev/null 2>&1; then
    local _drm _d _cand; _drm="$screen"
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
          done ;;
      esac
    fi
  fi
  if [ -n "$_mon" ]; then
    printf '%s\n' "$_mon" > "${dest}/hd_monitor.txt"; box_center "HD monitor: ${_mon}"
  fi
  rm -f "$tmp"; local current res chosen best_delta line id label hz milli delta
  if [ -n "$screen" ]; then
    current=$(batocera-resolution --screen "$screen" currentMode 2>/dev/null || true)
  else current=$(batocera-resolution currentMode 2>/dev/null || true); fi
  case "$current" in
    unknown*|""|640x480.*) current="" ;;
  esac
  res="${current%%.*}"; chosen=""; best_delta=999999
  while IFS= read -r line; do
    [[ "$line" == STACK=* ]] && continue; id="${line%%:*}"; label="${line#*:}"; [[ "$id" == max-* ]] && continue
    [[ "$id" != "${res}."* ]] && continue
    hz=$(echo "$label" | awk '{print $(NF-1)}')
    milli=$(echo "$hz" | awk '{printf "%d", ($1 * 1000) + 0.5}')
    [ -z "$milli" ] && continue
    if [ "$milli" -gt 60000 ]; then
      delta=$((milli - 60000))
    else delta=$((60000 - milli)); fi
    if [ "$delta" -lt "$best_delta" ]; then
      best_delta=$delta; chosen=$id
    fi
  done < "${dest}/hd_mode_list.txt"
  if [ -z "$chosen" ]; then
    local best_px=0 px; best_delta=999999
    while IFS= read -r line; do
      [[ "$line" == STACK=* ]] && continue; id="${line%%:*}"; label="${line#*:}"; [[ "$id" == max-* ]] && continue
      res="${id%%.*}"; w="${res%%x*}"; h="${res#*x}"
      case "$w" in *[!0-9]*) continue ;; esac
      case "$h" in *[!0-9]*) continue ;; esac
      px=$((w * h))
      [ "$px" -lt "$best_px" ] && continue
      hz=$(echo "$label" | awk '{print $(NF-1)}')
      milli=$(echo "$hz" | awk '{printf "%d", ($1 * 1000) + 0.5}')
      [ -z "$milli" ] && continue
      if [ "$milli" -gt 60000 ]; then
        delta=$((milli - 60000))
      else delta=$((60000 - milli)); fi
      if [ "$px" -gt "$best_px" ] || [ "$delta" -lt "$best_delta" ]; then
        best_px=$px; best_delta=$delta; chosen=$id
      fi
    done < "${dest}/hd_mode_list.txt"
  fi
  if [ -n "$chosen" ]; then
    echo "global.videomode=$chosen" > "${dest}/video_mode.txt"
    echo "es.resolution=$chosen" > "${dest}/es_resolution.txt"
    box_center "Saved HD monitor list. Preselected ${chosen}."
  else box_center "Saved HD monitor list."; fi
}
backup_once() {
  msg "==> Preparing first-run BACKUP…"; mkdir -p "$BACKUP_ROOT"; local ok_count=0 miss_count=0
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
  mkdir -p "$BASE_DIR"; date +"%Y-%m-%d %H:%M:%S" > "$CHECK_FILE"
  if [ ! -s /userdata/Batocera-CRT-Script-Backup/mode_backups/hd_mode/video_settings/hd_mode_list.txt ]; then capture_hd_monitor_list; fi
  box_hash; box_center "System restore backup created"; box_empty
  box_center "A baseline backup of your Batocera system files was made"
  box_center "before any script changes. You can use it later to return to"
  box_center "a clean/default Batocera installation."; box_empty
  box_center "Your games and save files are not touched."; box_empty
  box_center "Captured files: ${GREEN}${ok_count}${NOCOLOR}   Missing/skipped: ${YELLOW}${miss_count}${NOCOLOR}"
  box_center "Restore checkpoint: ${BLUE}${CHECK_FILE}${NOCOLOR}"; box_hash
  prompt_centered_tty "Press ${BLUE}ENTER${NOCOLOR} to continue…"
}
remount_boot_rw() {
  msg "==> Remounting /boot as read-write…"; mount -o remount,rw /boot 2>/dev/null || true
}
prompt_when_backup_exists() {
  local LOG_FILE="${CRT_LOG}"; box_hash; box_center "${BOLD}A backup was found${NOCOLOR}"; box_empty
  box_center "Run the installer again (Press Enter or 1)"
  box_center "Restore to stock Batocera (Remove the Script, Press 2)"; box_empty
  box_center "Your games and save files will ${GREEN}NOT${NOCOLOR} be deleted."; box_hash; local choice=""
  while :; do
    box_empty; box_center "Your choice (1) Enter or (2) Restore [1/2]:"; box_empty
    if [ -e /dev/tty ]; then
      IFS= read -r choice </dev/tty || choice=""
    else IFS= read -r choice || choice=""; fi
    printf "backup menu choice: %s\n" "${choice}" >> "$LOG_FILE"; choice="${choice:-1}"
    case "$choice" in
      1)
        box_center "Proceeding with installation/setup…"; printf "Proceeding with installation/setup…\n" >> "$LOG_FILE"
        BACKUP_CHOICE="1"; printf "\n"
        return 0 ;;
      2)
        box_center "Restoring stock Batocera (removing the Script)…"
        printf "Restoring stock Batocera (removing the Script)…\n" >> "$LOG_FILE"; restore_all
        exit 1 ;;
      *)
        box_empty; box_center "Please press 1 (or ENTER) to continue, or 2 to restore."
        box_empty ;;
    esac
  done
}
backup_restore_main() {
  mkdir -p "$BASE_DIR"
  if [ ! -f "$CHECK_FILE" ]; then
    backup_once; return 0
  else
    prompt_when_backup_exists; return 0
  fi
}
