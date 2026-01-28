#!/bin/bash

########################################################################################
#####################        TUI banner utilities start     		   #################
########################################################################################

# --- Colors (real ESCs) ---
RED=${RED:-$'\033[31m'}
GREEN=${GREEN:-$'\033[32m'}
YELLOW=${YELLOW:-$'\033[33m'}
BLUE=${BLUE:-$'\033[1;34m'}
CYAN=${CYAN:-$'\033[36m'}
MAGENTA=${MAGENTA:-$'\033[35m'}    
BOLD=${BOLD:-$'\033[1m'}
NOCOLOR=${NOCOLOR:-$'\033[0m'}

# --- Small TUI convenience helpers ---
say_press_enter() { box_center "Press ${BLUE}ENTER${NOCOLOR} to continue…"; }
say_press_key()   { box_center "Press ${BLUE}$1${NOCOLOR} to continue…"; }  # usage: say_press_key "R"

ok_box()   { box_hash; box_center "${GREEN}✔ $*${NOCOLOR}"; box_hash; }
warn_box() { box_hash; box_center "${YELLOW}⚠ $*${NOCOLOR}"; box_hash; }
err_box()  { box_hash; box_center "${RED}✖ $*${NOCOLOR}";  box_hash; }

# --- Global log target ---
LOG_FILE="${LOG_FILE:-/userdata/system/logs/BUILD_15KHz_Batocera.log}"

# --- Pipe helper: print AND append to log (no swallowing) ---
# Usage: something | _log_tee
type _log_tee >/dev/null 2>&1 || _log_tee() { tee -a "$LOG_FILE"; }

# Determine box width from terminal and clamp for aesthetics
if [ -t 1 ]; then
  cols=$(tput cols 2>/dev/null || printf "%s" 80)
else
  cols=80
fi
BOXW=$cols
[ "$BOXW" -lt 64 ] && BOXW=64
[ "$BOXW" -gt 110 ] && BOXW=110

border=$(printf "%${BOXW}s" | tr ' ' '#')
inner_w=$((BOXW - 4))  # space between the "##" borders

empty_line() {
  printf "##%*s##\n" "$inner_w" ""
}

# Center text inside the bordered box (handles ANSI and trims if needed)
center() {
  local s="$*"
  # Strip ANSI for width calc
  local plain
  plain="$(printf "%b" "$s" | sed 's/\x1B\[[0-9;]*[A-Za-z]//g')"
  local slen=${#plain}
  if [ $slen -gt $inner_w ]; then
    s="$(printf "%b" "$s" | sed 's/\x1B\[[0-9;]*[A-Za-z]//g' | cut -c -$inner_w)"
    plain="$s"
    slen=${#plain}
  fi
  local left=$(( (inner_w - slen) / 2 ))
  local right=$(( inner_w - slen - left ))
  printf "##%*s%b%*s##\n" "$left" "" "$s" "$right" ""
}

# Center a plain line (no box).
center_plain() {
  local s="$*"
  [ ${#s} -gt $BOXW ] && s="${s:0:$BOXW}"
  local left=$(( (BOXW - ${#s}) / 2 ))
  printf "%*s%s\n" "$left" "" "$s"
}

# ---------- Logging wrappers around existing TUI helpers ----------
# (These PRINT and LOG — no >/dev/null anywhere)

box_hash() {              # full-width ####...#### line + log
  printf "%s\n" "$border" | _log_tee
}

box_empty() {             # framed empty line + log
  empty_line | _log_tee
}

box_center() {            # centered framed line + log (ANSI-safe centering already done)
  center "$*" | _log_tee
}

# ===== Sea Islands helpers (idempotent) =====
if ! declare -F is_sea_islands_chip >/dev/null 2>&1; then
is_sea_islands_chip() {
  local hint="${CHIP_FAMILY:-}"
  if [ -z "$hint" ]; then
    local l=""
    if command -v lspci >/dev/null 2>&1; then
      l="$(lspci -s "${AMD_PCI_ADDR#0000:}" -nn 2>/dev/null | tr '[:upper:]' '[:lower:]')"
    fi
    hint="$l"
  fi
  printf '%s' "$hint" | grep -qiE '(chip_)?(bonaire|hawaii|kaveri|kabini|mullins)' && return 0
  printf '%s' "$hint" | grep -qiE '(kalindi|spectre|spooky)' && return 0
  return 1
}
fi

if ! declare -F get_bound_driver >/dev/null 2>&1; then
get_bound_driver() {
  local dev="/sys/class/drm/card${AMD_CARD_INDEX}/device"
  local drv=""; drv="$(basename "$(readlink -f "$dev/driver" 2>/dev/null)" 2>/dev/null || true)"
  printf '%s' "$drv"
}
fi

if ! declare -F offer_switch_to_radeon >/dev/null 2>&1; then
offer_switch_to_radeon() {
  local conf="/boot/batocera-boot.conf"
  local bak="/boot/batocera-boot.conf.bak_sea_islands"
  echo "Sea Islands: offering driver switch; editing $conf with backup $bak" >> /userdata/system/logs/BUILD_15KHz_Batocera.log

  box_hash
  box_center "Sea Islands (GCN 2.x / DCE 8.x) detected under ${GREEN}amdgpu${NOCOLOR}."
  box_center "Interlace is ${RED}unsupported${NOCOLOR} on amdgpu for this family."
  box_empty
  box_center "Recommended: switch to ${GREEN}radeon${NOCOLOR} driver in /boot/batocera-boot.conf"
  box_center "(this sets: amdgpu=false)"
  box_hash
  prompt_centered_tty "PRESS ${BLUE}ENTER${NOCOLOR} TO APPLY (or Ctrl+C to keep amdgpu)"

  mount -o remount,rw /boot 2>/dev/null || true
  cp -f "$conf" "$bak" 2>/dev/null || true

  if grep -q '^ *amdgpu=' "$conf" 2>/dev/null; then
    sed -i 's/^ *amdgpu=.*/amdgpu=false/' "$conf"
  else
    printf '\n# Force radeon for Sea Islands (GCN 2.x)\namdgpu=false\n' >> "$conf"
  fi

  sync
  box_hash
  box_center "batocera-boot.conf updated (${GREEN}amdgpu=false${NOCOLOR})."
  box_center "Reboot to load the radeon driver and enable interlace."
  box_hash
  echo "Sea Islands: wrote amdgpu=false to $conf (backup at $bak)" >> /userdata/system/logs/BUILD_15KHz_Batocera.log

  # --- Safe immediate reboot (with cancel window) ---
  box_empty
  box_center "Reboot required to load ${GREEN}radeon${NOCOLOR}."
  box_center "System will reboot in 15 seconds…  (press Ctrl+C to cancel)"
  box_hash

  sync
  mount -o remount,ro /boot 2>/dev/null || true

  for s in $(seq 15 -1 1); do
    printf "\rRebooting in %2d s…  " "$s"
    sleep 1
  done
  echo
  echo "Sea Islands: initiating reboot now." >> /userdata/system/logs/BUILD_15KHz_Batocera.log
  reboot
}
fi
# ===== End Sea Islands helpers =====



# Left-aligned content inside the box (ANSI-safe, trimmed, logged)
box_left() {
  local s="$*"

  # Normalize tabs
  s="${s//$'\t'/ }"

  # Visible length without ANSI
  local plain
  plain="$(printf "%b" "$s" | sed 's/\x1B\[[0-9;]*[A-Za-z]//g')"

  # We reserve 1 leading space after '##', so effective inner width shrinks by 1
  local eff_w=$(( inner_w - 1 ))

  # Trim by visible length if needed
  if [ ${#plain} -gt "$eff_w" ]; then
    plain="${plain:0:$eff_w}"
    s="$plain"
  fi

  # Right padding to fill the line cleanly
  local pad=$(( eff_w - ${#plain} ))

  # Exact frame: '## ' + content + pad + '##'
  printf '## %b%*s##\n' "$s" "$pad" '' | _log_tee
}

center_plain_log() {      # centered plain line + log
  center_plain "$*" | _log_tee
}

# Centered prompt (ENTER gate) that works even if stdin is not a TTY
prompt_centered_tty() {
  box_center "$*"
  if [ -e /dev/tty ]; then
    # Read from the actual terminal; never fail the script if read gets EOF
    read -r </dev/tty || true
  else
    # Fallback if no TTY is available: short grace countdown
    for s in 5 4 3 2 1; do
      box_center "Continuing in $s…"
      sleep 1
    done
  fi
}

# Simple prompt that reads from current stdin (use only if stdin is interactive)
prompt_centered() {
  box_center "$*"
  read -r
}

# Nice section title block (hash, empty, centered title, empty, hash)
box_title() {
  box_hash
  box_empty
  box_center "$*"
  box_empty
  box_hash
}

# Center a framed line and print+log (alias matching your restore style)
type center_both >/dev/null 2>&1 || center_both() { center "$*" | _log_tee; }

####################################################################################
# FINAL MESSAGE: First-boot instructions + reboot prompt (uses TUI helpers) START  #
####################################################################################
show_first_boot_instructions_and_reboot() {
  # Safety: fallbacks if color vars aren't defined
  : "${BOLD:="\e[1m"}" "${GREEN:="\e[32m"}" "${YELLOW:="\e[33m"}" "${NOCOLOR:="\e[0m"}"

  # If running over SSH, show a small notice (kept ASCII-safe)
  if [[ -n "${SSH_CONNECTION:-}" ]]; then
    box_hash
    box_center "${BOLD}Notice:${NOCOLOR} You are running over SSH."
    box_center "The system will reboot after you press ENTER."
    box_hash
  fi

  box_hash
  box_center "${BOLD}First Boot After Installation - Setup Instructions${NOCOLOR}"
  box_hash
  box_center ""
  box_center "Once your system is rebooted ${BOLD}${YELLOW}with the CRT Script installed${NOCOLOR}, you must do the following:"
  box_center ""
  box_center "1) Go to:  MAIN MENU -> SYSTEM SETTINGS -> HARDWARE"
  box_center ""
  box_center "2) Set these values:"
  box_center "    ${BOLD}VIDEO OUTPUT:${NOCOLOR}  Set this to the correct connected output (there should only be one listed)."
  box_center "    ${BOLD}VIDEO MODE:${NOCOLOR}   Set this based on your chosen profile:"
  box_center ""
  box_center "${BOLD}For 15kHz CRT Profiles${NOCOLOR}"
  box_center "   640x480   ->  Boot_480i 1.0:0:0 15KHz 60Hz"
  box_center "   768x576   ->  Boot_576i 1.0:0:0 15KHz 50Hz"
  box_center ""
  box_center "${BOLD}For 31kHz (VGA) Profiles${NOCOLOR}"
  box_center "   640x480   ->  Boot_480i 1.0:0:0 31KHz 60Hz"
  box_center ""
  box_center "[*] All profiles will have a ${BOLD}Boot_${NOCOLOR} prefix in the list."
  box_center "[*] Make sure the ${BOLD}Boot_${NOCOLOR} entry you select matches the ${BOLD}exact resolution${NOCOLOR} you picked during installation."
  box_center ""
  box_hash
  box_center ""
  box_center "${GREEN}${BOLD}Press ENTER to reboot now...${NOCOLOR}"
  box_center ""
  box_hash
  echo
  # Wait for user, then reboot
  read -r
  reboot
}

####################################################################################
# FINAL MESSAGE: First-boot instructions + reboot prompt (uses TUI helpers) END    #
####################################################################################

########################################################################################
#####################        TUI banner utilities end     			   #################
########################################################################################

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

# >>> Call the backup/restore entry-point now, then continue with the rest of the script:
backup_restore_main || exit 1
########################################################################################
#####################                 BACKUP EXIST END		   		   #################
########################################################################################


# -----------------------------------------------------------------------------
# Install /boot/boot-custom.sh for AMD / NVIDIA (nouveau) ONLY.
# Skip when Intel iGPU is present OR NVIDIA proprietary drivers are in use.
# Source: /userdata/system/Batocera-CRT-Script/UsrBin_configs/boot-custom.sh
# Dest:   /boot/boot-custom.sh (chmod 0755)
# -----------------------------------------------------------------------------
maybe_install_boot_custom_sh() {
  local LOG_FILE="/userdata/system/logs/BUILD_15KHz_Batocera.log"
  local SRC="/userdata/system/Batocera-CRT-Script/UsrBin_configs/boot-custom.sh"
  local DST="/boot/boot-custom.sh"

  # --- Detect Intel iGPU (skip if present) -----------------------------------
  # Primary: DRM vendor 0x8086; Fallbacks: loaded i915 or lspci match.
  local intel_gpu=0
  for v in /sys/class/drm/card*/device/vendor; do
    if [ -f "$v" ] && grep -qi '^0x8086' "$v"; then
      intel_gpu=1
      break
    fi
  done
  if [ "$intel_gpu" -eq 0 ] && lsmod 2>/dev/null | grep -q '^i915'; then
    intel_gpu=1
  fi
  if [ "$intel_gpu" -eq 0 ] && command -v lspci >/dev/null 2>&1; then
    if lspci -nn | grep -Eiq 'VGA|3D' && lspci -nn | grep -Eiq 'Intel.*(VGA|3D)'; then
      intel_gpu=1
    fi
  fi

  # --- Decide proprietary vs non-proprietary NVIDIA deterministically -------
  local choice="${Drivers_Nvidia_CHOICE:-}"
  local choice_up="${choice^^}"
  local proprietary_nvidia=0
  case "$choice_up" in
    NVIDIA_DRIVERS) proprietary_nvidia=1 ;;   # explicit proprietary
    NOUVEAU)        proprietary_nvidia=0 ;;   # explicit nouveau
    *)  # unknown - use fallbacks
        if [ -f /userdata/system/99-nvidia.conf ]; then
          proprietary_nvidia=1
        elif lsmod 2>/dev/null | grep -q '^nvidia'; then
          proprietary_nvidia=1
        fi
        ;;
  esac

  # Debug breadcrumbs
  {
    echo "boot-custom: Drivers_Nvidia_CHOICE='${choice}' (norm='${choice_up}')"
    echo "boot-custom: 99-nvidia.conf: $([ -f /userdata/system/99-nvidia.conf ] && echo present || echo absent)"
    echo "boot-custom: lsmod nvidia: $(lsmod 2>/dev/null | grep -q '^nvidia' && echo present || echo absent)"
    echo "boot-custom: proprietary_nvidia=${proprietary_nvidia}"
    echo "boot-custom: intel_gpu=${intel_gpu}"
  } >> "$LOG_FILE"

  # --- Skip conditions -------------------------------------------------------
  if [ "$proprietary_nvidia" -eq 1 ]; then
    echo "boot-custom: SKIP (NVIDIA proprietary detected)" >> "$LOG_FILE"
    box_hash
    box_center "Skipping ${BLUE}boot-custom.sh${NOCOLOR} install (NVIDIA proprietary driver)."
    box_hash
    return 0
  fi

  if [ "$intel_gpu" -eq 1 ]; then
    echo "boot-custom: SKIP (Intel iGPU detected)" >> "$LOG_FILE"
    box_hash
    box_center "Skipping ${BLUE}boot-custom.sh${NOCOLOR} install (Intel iGPU)."
    box_hash
    return 0
  fi

  # --- Skip for 31 kHz / multisync profiles ---------------------------------
  # Only install boot-custom.sh for 15-25 kHz workflows.
  # Profiles to SKIP:
  # arcade_31 arcade_15_31 arcade_15_25_31 m2929 d9200 d9400 d9800 m3129
  # pstar ms2930 r666b pc_31_120 pc_70_120 vesa_480 vesa_600 vesa_768 vesa_1024
  local sel="${monitor_firmware:-}"
  case "$sel" in
    arcade_31|arcade_15_31|arcade_15_25_31|m2929|d9200|d9400|d9800|m3129| \
    pstar|ms2930|r666b|pc_31_120|pc_70_120|vesa_480|vesa_600|vesa_768|vesa_1024)
      echo "boot-custom: SKIP (profile=${sel})" >> "$LOG_FILE"
      box_hash
      box_center "Skipping ${BLUE}boot-custom.sh${NOCOLOR} (profile: ${sel})."
      box_hash
      return 0
      ;;
  esac

  # --- Proceed for AMD or NVIDIA (nouveau) -----------------------------------
  if [ ! -f "$SRC" ]; then
    echo "boot-custom: source not found: $SRC" >> "$LOG_FILE"
    box_hash
    box_center "${YELLOW}boot-custom.sh not found at:${NOCOLOR}"
    box_center "${BLUE}${SRC}${NOCOLOR}"
    box_hash
    return 0
  fi

  if [ -f "$DST" ] && cmp -s "$SRC" "$DST"; then
    echo "boot-custom: already up-to-date at $DST" >> "$LOG_FILE"
    box_hash
    box_center "boot-custom.sh is already up-to-date in ${BLUE}/boot/${NOCOLOR}."
    box_hash
    return 0
  fi

  echo "boot-custom: installing $SRC -> $DST" >> "$LOG_FILE"
  mount -o remount,rw /boot 2>/dev/null || true
  if cp -f "$SRC" "$DST"; then
    chmod 0755 "$DST" 2>/dev/null || true
    sync
    echo "boot-custom: installed OK (0755) -> $DST" >> "$LOG_FILE"
    box_hash
    box_center "Installed ${GREEN}boot-custom.sh${NOCOLOR} to ${BLUE}/boot/${NOCOLOR} (0755)."
    box_hash
  else
    echo "boot-custom: COPY FAILED ($SRC -> $DST)" >> "$LOG_FILE"
    box_hash
    box_center "${RED}Failed to install boot-custom.sh to /boot${NOCOLOR}"
    box_hash
  fi
  mount -o remount,ro /boot 2>/dev/null || true

  return 0
}
# ----------------------------------------------------------------------------- end



# ─────────────────────────────────────────────────────────────────────────────
# New output detection & persistence (terminal-only) as a function Start
# Call this AFTER GPU preflight (e.g., after the R9 380/380X block).
# ─────────────────────────────────────────────────────────────────────────────

# Deterministic XR ↔ DRM resolver with logging
#
# Behavior:
# 1) Deterministic path: read CONNECTOR_ID for the given XRandR output via `xrandr --prop`,
#    then find the matching /sys/class/drm/card*-*/connector_id with the same value.
#    This gives a true 1:1 mapping on amdgpu, i915, and nouveau.
# 2) Fallback: if CONNECTOR_ID is missing or not found in sysfs, use the original heuristic
#    (alias match first, then family+index with DVI-I > DVI-D > DVI-A).
#
# Card preference:
# - If a preferred card is provided (arg $2 or $AMD_CARD_INDEX), search is constrained to that card.
#
# Notes:
# - Does not use "connected" status as a tie-breaker, so disconnected outputs still resolve.
# - NVIDIA proprietary is not supported by the deterministic path; the fallback may still work
#   but is not guaranteed to be correct on that driver.
#
# Args:
#   $1 = XRandR output name (e.g., DP-1, HDMI-2, DVI-I-1)
#   $2 = optional preferred card index (e.g., 0). If empty, all cards are scanned.
#
# Returns:
#   DRM connector token without the "cardX-" prefix (e.g., DP-1, HDMI-A-1, DVI-I-1).
map_xrandr_to_drm() {
  local xr="$1"
  local pref_card="${2:-${AMD_CARD_INDEX:-}}"
  [ -z "$xr" ] && return 1

  # Logging helpers
  local _LOG="${LOG_FILE:-/userdata/system/logs/BUILD_15KHz_Batocera.log}"
  local MAP_LOG_VERBOSE="${MAP_LOG_VERBOSE:-0}"
  _log() { echo "map_xrandr_to_drm: $*" >> "$_LOG"; }

  _log "------------------------------------------------------------"
  _log "XR input='${xr}'  pref_card='${pref_card:-*}'"

  # ------------------------------------------------------------
  # 1) Deterministic path: CONNECTOR_ID join (amdgpu/i915/nouveau)
  #     xrandr --prop -> CONNECTOR_ID -> /sys/class/drm/.../connector_id 
  # ------------------------------------------------------------

  local cid=""
  if command -v xrandr >/dev/null 2>&1; then
	cid="$(DISPLAY=${DISPLAY:-:0} xrandr --prop 2>/dev/null | awk -v o="$xr" '
	$1==o {f=1}
	f && /CONNECTOR_ID:/ {print $2; exit}
	# end section if we hit another connector header
	f && /^[A-Za-z0-9-]+[[:space:]]+(connected|disconnected)/ && $1!=o {exit}
	')"

    if [[ "$cid" =~ ^[0-9]+$ ]]; then
      local search_glob match=""
      if [ -n "$pref_card" ]; then
        search_glob="/sys/class/drm/card${pref_card}-*/connector_id"
      else
        search_glob="/sys/class/drm/card*-*/connector_id"
      fi

      shopt -s nullglob
      for f in $search_glob; do
        if [ -r "$f" ] && [ "$(cat "$f" 2>/dev/null)" = "$cid" ]; then
          match="${f%/connector_id}"
          break
        fi
      done
      shopt -u nullglob

      if [ -n "$match" ]; then
        local base card_idx drm_out
        base="$(basename -- "$match")"
        if [[ "$base" =~ ^card([0-9]+)-(.+)$ ]]; then
          card_idx="${BASH_REMATCH[1]}"
          drm_out="${BASH_REMATCH[2]}"
          _log "CID match: XR='${xr}' CID=${cid} -> ${base} (card=${card_idx})"
          printf '%s\n' "$drm_out"
          return 0
        fi
      else
        _log "CID not found in sysfs for XR='${xr}' CID=${cid}; falling back to heuristic."
      fi
    else
      _log "No CONNECTOR_ID for XR='${xr}'; falling back to heuristic."
    fi
  else
    _log "xrandr not available; falling back to heuristic."
  fi

  # ------------------------------------------------------------
  # 2) Fallback: original heuristic from this script
  #     - Exact alias match (e.g., HDMI-1 == HDMI-A-1, DVI-I-1 stays DVI-I-1)
  #     - Else family+index with DVI-I > DVI-D > DVI-A
  #     - Honors preferred card if provided
  # ------------------------------------------------------------

  # --- Parse XR (keep subtype + full index chain, supports MST like 1-1) ---
  local xr_type_full xr_index_chain
  case "$xr" in
    DVI-I-*|DVI-D-*|DVI-A-*)
      xr_type_full="${xr%%-[0-9]*}"
      xr_index_chain="${xr#${xr_type_full}-}"
      ;;
    *)
      xr_type_full="${xr%%-*}"
      xr_index_chain="${xr#${xr_type_full}-}"
      ;;
  esac

  # Canonicalize some user-facing tokens to families we recognize
  # DisplayPort -> DP, USB-C -> DP, HDMI -> HDMI/HDMI-A (handled later)
  case "$xr_type_full" in
    DisplayPort) xr_type_full="DP" ;;
    USB-C|USBC|Type-C|USB) xr_type_full="DP" ;;
    HDMI-A|HDMI) : ;;
    DVI-I|DVI-D|DVI-A|DVI) : ;;
    eDP|LVDS|VGA) : ;;
    *) : ;;
  esac

  # Snapshot all DRM connectors; prefer pref_card if set
  local best_exact="" best_exact_card=""
  local best_family="" best_family_card="" best_family_rank=99

  # sysfs walk: /sys/class/drm/cardX-<connector>
  shopt -s nullglob
  for p in /sys/class/drm/card*-*; do
    b="$(basename "$p")" || continue
    [[ "$b" =~ ^card([0-9]+)-(.+)$ ]] || continue
    card_idx="${BASH_REMATCH[1]}"
    drm_name="${BASH_REMATCH[2]}"

    # --- Parse DRM name robustly (preserve subtypes like DVI-I / HDMI-A) ---
    # If connector is DVI-*-N or HDMI-A-N, keep the subtype token
    if [[ "$drm_name" == DVI-*-* || "$drm_name" == HDMI-A-* ]]; then
      drm_type="${drm_name%%-[0-9]*}"          # DVI-I or DVI-D or DVI-A, or HDMI-A
      drm_idx_chain="${drm_name#${drm_type}-}" # e.g., "1" or "1-1"
    else
      drm_type="${drm_name%%-*}"               # DP / eDP / LVDS / VGA / HDMI (no -A) / etc.
      drm_idx_chain="${drm_name#${drm_type}-}" # e.g., "1" or "1-1"
    fi

    # Generate XR-style aliases we consider "exact" for this sysfs entry
    # e.g. card0-HDMI-A-1 => exact alias: HDMI-A-1 and HDMI-1
    exact1="${drm_name}"
    case "$drm_type" in
      DP)                alias2="DisplayPort-${drm_idx_chain}" ;;
      HDMI|HDMI-A)       alias2="HDMI-${drm_idx_chain}" ;;
      DVI-I|DVI-D|DVI-A) alias2="DVI-${drm_idx_chain}" ;;
      *)                 alias2="" ;;
    esac

    # Card preference gate (if set, ignore other cards)
    if [ -n "$pref_card" ] && [ "$card_idx" != "$pref_card" ]; then
      continue
    fi

    # 2.1) exact alias match on either exact1 or alias2
    if [ "$xr" = "$exact1" ] || [ -n "$alias2" ] && [ "$xr" = "$alias2" ]; then
      best_exact="$drm_name"
      best_exact_card="$card_idx"
      _log "EXACT alias: XR='${xr}' -> '${drm_name}' (card${card_idx})"
      # don't break; we still want to ensure we prefer the preferred card if multiple
      if [ -n "$pref_card" ]; then
        # already constrained by card, so we can finish
        printf '%s\n' "$best_exact"
        return 0
      fi
      continue
    fi

    # 2.2) Family+index (ranked)
    # Map XR family to DRM family token and choose rank for DVI variants
    family_rank=99
    case "$xr_type_full" in
      DP)
        if [ "$drm_type" = "DP" ] && [ "$drm_idx_chain" = "$xr_index_chain" ]; then
          family_rank=0
        fi
        ;;
      HDMI|HDMI-A)
        if { [ "$drm_type" = "HDMI-A" ] || [ "$drm_type" = "HDMI" ]; } \
           && [ "$drm_idx_chain" = "$xr_index_chain" ]; then
          family_rank=0
        fi
        ;;
      DVI|DVI-I|DVI-D|DVI-A)
        if [[ "$drm_type" =~ ^DVI-(I|D|A)$ ]] && [ "$drm_idx_chain" = "$xr_index_chain" ]; then
          case "$drm_type" in
            DVI-I) family_rank=0 ;;
            DVI-D) family_rank=1 ;;
            DVI-A) family_rank=2 ;;
          esac
        fi
        ;;
      eDP|LVDS|VGA)
        if [ "$drm_type" = "$xr_type_full" ] && [ "$drm_idx_chain" = "$xr_index_chain" ]; then
          family_rank=0
        fi
        ;;
    esac

    if [ "$family_rank" -lt "$best_family_rank" ]; then
      best_family="$drm_name"
      best_family_card="$card_idx"
      best_family_rank="$family_rank"
      _log "FAMILY candidate: XR='${xr}' -> '${drm_name}' (card${card_idx} rank=${family_rank})"
    fi
  done
  shopt -u nullglob

  # Prefer exact (on any card) over family match
  if [ -n "$best_exact" ]; then
    _log "RESOLVE exact (card${best_exact_card}): '${best_exact}'"
    printf '%s\n' "$best_exact"; return 0
  fi
  if [ -n "$best_family" ]; then
    _log "RESOLVE family (card${best_family_card} rank=${best_family_rank}): '${best_family}'"
    printf '%s\n' "$best_family"; return 0
  fi

  # Last resort: conservative guess (keeps subtype if XR provided one)
  local guess=""
  case "$xr_type_full" in
    DisplayPort) guess="DP-${xr_index_chain}" ;;
    HDMI-A)      guess="HDMI-A-${xr_index_chain}" ;;
    HDMI)        guess="HDMI-A-${xr_index_chain}" ;;
    DVI-I|DVI-D|DVI-A) guess="${xr_type_full}-${xr_index_chain}" ;;
    DVI)         guess="DVI-I-${xr_index_chain}" ;;
    eDP|LVDS|VGA) guess="${xr_type_full}-${xr_index_chain}" ;;
    USB-C|USBC|Type-C|USB) guess="DP-${xr_index_chain}" ;;
    *)           guess="${xr_type_full}-${xr_index_chain}" ;;
  esac
  _log "RESOLVE guess: '${guess}'"
  printf '%s\n' "$guess"
  return 0
}

# Snapshot of DRM connectors → XR-style aliases (logged for debugging)
log_drm_map_snapshot() {
  echo "---- DRM connector snapshot (pref card: ${AMD_CARD_INDEX:-*}) ----" >> "$LOG_FILE"
  for p in /sys/class/drm/card*-*; do
    b="$(basename "$p")"
    name="${b#card*-}"
    t="${name%%-*}"
    idx="${name#${t}-}"
    case "$t" in
      DP)                xr1="DisplayPort-${idx}"; xr2="DP-${idx}" ;;
      HDMI|HDMI-A)       xr1="HDMI-${idx}";       xr2="HDMI-A-${idx}" ;;
      DVI-I|DVI-D|DVI-A) xr1="${t}-${idx}";       xr2="DVI-${idx}" ;;
      *)                 xr1="${t}-${idx}";       xr2="" ;;
    esac
    # Prefer the bound AMD card if known; otherwise log all
    if [ -n "${AMD_CARD_INDEX-}" ] && [[ "$b" != card${AMD_CARD_INDEX}-* ]]; then
      continue
    fi
    echo "card${b#card}-  DRM:${name}  XR-candidates: ${xr1}${xr2:+, ${xr2}}" >> "$LOG_FILE"
  done
  echo "--------------------------------" >> "$LOG_FILE"
}

output_detection_and_persist() {
  # XRandR-only output detection and persistence into 10-monitor.conf

  export LC_ALL=C
  export LANG=C
  export DISPLAY="${DISPLAY:-:0}"

  CONF_DIR="/etc/X11/xorg.conf.d"
  CONF_FILE="$CONF_DIR/10-monitor.conf"
  FLAG_FILE="$CHECK_FILE"

  die() { echo "ERROR: $*" >&2; exit 1; }
  timestamp() { date +"%Y.%m.%d,%H.%M.%S"; }
  sanitize_conn() { sed 's/\r//g' | sed 's/[^A-Za-z0-9._:+-]//g'; }
  create_flag_file() { echo "$(timestamp)" > "$FLAG_FILE"; }

  box_title "Output detection (XRandR only)"
  echo "XRandR-only path engaged" >> "$LOG_FILE"

  # 1) Query xrandr once; if X not ready, retry a few times
  ALL_OUTS=()
  CONN_OUTS=()
  for attempt in 1 2 3 4 5; do
	if DISPLAY=${DISPLAY:-:0} xrandr --query >/dev/null 2>&1; then
	mapfile -t XR < <(DISPLAY=${DISPLAY:-:0} xrandr --query 2>/dev/null \
		| awk '/^[^ ]+[[:space:]]+(connected|disconnected)/ {print $1, $2}' \
		| grep -Eiv '^(Writeback|Virtual|VIRTUAL)')

      ALL_OUTS=()
      CONN_OUTS=()
      for ln in "${XR[@]}"; do
        n="${ln%% *}"; st="${ln##* }"
        [ -n "$n" ] || continue
        case "$st" in
          connected) CONN_OUTS+=("$n");;
        esac
        ALL_OUTS+=("$n")
      done
      [ ${#ALL_OUTS[@]} -gt 0 ] && break
    fi
    sleep 1
  done

  if [ ${#ALL_OUTS[@]} -eq 0 ]; then
    box_left "No outputs found via xrandr. Is X running?"
    die "Cannot proceed without xrandr outputs."
  fi

  # 1) If an old config exists: backup → remove → save overlay → reboot NOW
  if [ -f "$CONF_FILE" ]; then
    box_hash
    box_center "Existing Xorg monitor configuration detected:"
    box_center "$CONF_FILE"
    box_empty
    box_center "This file must be removed and the system must reboot before setup runs again."

    backup="${CONF_FILE}.$(timestamp)"
    mv -- "$CONF_FILE" "$backup"
    chmod 000 "$backup" || true

    box_center "Backed up to: $backup"
    batocera-save-overlay >>"$LOG_FILE" 2>&1 || true

    box_empty
    box_center "System will reboot to finish cleanup."
    prompt_centered_tty "PRESS ${GREEN}ENTER${NOCOLOR} TO CONTINUE"
    box_hash

    reboot
    exit 0
  fi

  # 2) If nothing connected, we still allow choosing any port (for DACs/switchers)
  if [ ${#CONN_OUTS[@]} -eq 0 ]; then
    box_left "0 connected outputs reported by xrandr. You can still pick a port to keep active."
  fi
    log_drm_map_snapshot
  # 3) Print choices and prompt
  box_empty
  box_left "Detected outputs (xrandr):"
  idx=1
  for o in "${ALL_OUTS[@]}"; do
    st="disconnected"
    if printf '%s\n' "${CONN_OUTS[@]}" | grep -qx "$o"; then st="connected"; fi
    box_left "  [$idx] $o  ($st)"
    idx=$((idx+1))
  done
  box_empty

  # --- Quick, one-shot rescan via xrandr (no retries, no sleeps) ---
  quick_rescan_outputs() {
	mapfile -t XR < <(DISPLAY=${DISPLAY:-:0} xrandr --query 2>/dev/null \
	  | awk '/^[^ ]+[[:space:]]+(connected|disconnected)/ {print $1, $2}' \
	  | grep -Eiv '^(Writeback|Virtual|VIRTUAL)')

    ALL_OUTS=()
    CONN_OUTS=()
    for ln in "${XR[@]}"; do
      n="${ln%% *}"; st="${ln##* }"
      [ -n "$n" ] || continue
      [ "$st" = "connected" ] && CONN_OUTS+=("$n")
      ALL_OUTS+=("$n")
    done
    echo "Quick rescan: found ${#ALL_OUTS[@]} outputs; connected=${#CONN_OUTS[@]}" >> "$LOG_FILE"
  }

  while :; do
    # A small centered "input box"
    box_hash
    box_empty
    box_center "Enter the number of the output you like to use for CRT output"
    box_center "(press R to rescan outputs once via xrandr)"
    box_empty
    box_hash

    # Center the input cursor using spaces. BOXW is your inner width (used by box_* helpers).
    # We want the caret to start near the center (adjust -2 if you want it a tad left/right).
    pad=$(( (BOXW / 2) - 2 ))
    [ "$pad" -lt 0 ] && pad=0

    # Read the selection with a centered-looking prompt line (not framed).
    # The spaces align the caret; feels like an input field under the box.
    read -rp "$(printf '%*s> ' "$pad")" sel

    # Allow quick one-shot rescan with R/r
    if [[ "$sel" =~ ^[Rr]$ ]]; then
      box_hash
      box_center "Rescanning outputs (single xrandr --query)…"
      box_hash
      quick_rescan_outputs
        log_drm_map_snapshot
      # Reprint the (possibly updated) list
      box_empty
      box_center "Detected outputs (xrandr)"
      idx=1
      for o in "${ALL_OUTS[@]}"; do
        st="disconnected"
        if printf '%s\n' "${CONN_OUTS[@]}" | grep -qx "$o"; then st="connected"; fi
        box_center "  [$idx] $o  ($st)"
        idx=$((idx+1))
      done
      box_empty
      continue
    fi

    # Validate numeric selection
    if ! [[ "$sel" =~ ^[0-9]+$ ]]; then
      box_center "Please enter a number (or press R to rescan)."
      continue
    fi
    if ! { [ "$sel" -ge 1 ] && [ "$sel" -le ${#ALL_OUTS[@]} ]; }; then
      box_center "Out of range. Valid: 1..${#ALL_OUTS[@]} (or press R to rescan)."
      continue
    fi
    CHOSEN="${ALL_OUTS[$((sel-1))]}"
  # Keep xrandr name for Xorg; also compute DRM connector name for syslinux
  video_output_xrandr="$CHOSEN"
  # Prefer the bound AMD card if we have it; harmless if empty on Intel/NVIDIA
  KERNEL_CONN_NAME="$(map_xrandr_to_drm "$CHOSEN" "${AMD_CARD_INDEX:-}")"
  echo "XR->DRM mapping: '$CHOSEN' -> '${KERNEL_CONN_NAME}'" >> "$LOG_FILE"

  # Safety check: verify the resolved DRM connector actually exists in sysfs
  if ! compgen -G "/sys/class/drm/card${AMD_CARD_INDEX:-*}-${KERNEL_CONN_NAME}" >/dev/null; then
    echo "WARN: Could not verify DRM connector card${AMD_CARD_INDEX:-*}-${KERNEL_CONN_NAME} in sysfs." >> "$LOG_FILE"
    box_center "Warning: couldn't verify ${KERNEL_CONN_NAME} under /sys/class/drm. Using it anyway."
  fi

  # On-screen banner: show both names
  box_empty
  box_center "Selected output (XR): ${BLUE}${video_output_xrandr}${NOCOLOR}"
  box_center "Kernel connector (DRM/syslinux): ${GREEN}${KERNEL_CONN_NAME}${NOCOLOR}"
  box_empty

  break
done

  # 4) Recheck chosen status (xrandr-only) after a short settle (optional)
  sleep 1
  if DISPLAY=:0 xrandr --query >/dev/null 2>&1; then
    chosen_status="$(DISPLAY=:0 xrandr --query | awk -v c="$CHOSEN" '$1==c {print $2; exit}')"
    if [ "$chosen_status" != "connected" ]; then
      box_left "${CHOSEN} is currently reported as DISCONNECTED by xrandr. Proceeding anyway."
    else
      box_left "${CHOSEN} is CONNECTED."
    fi
  fi

  # 5) Build 'others' list
  OTHERS=()
  for o in "${ALL_OUTS[@]}"; do
    [ "$o" != "$CHOSEN" ] && OTHERS+=("$o")
  done

  # 6) Persist to 10-monitor.conf (always ignore others)
  mkdir -p "$CONF_DIR"
  {
    echo "# Generated by Batocera-CRT-Script (XRandR-only)"
    echo "# Disables all outputs except the selected one"
    echo
    for o in "${OTHERS[@]}"; do
      o="$(printf '%s' "$o" | sanitize_conn)"
      echo 'Section "Monitor"'
      echo "    Identifier \"$o\""
      echo '    Option "Ignore" "true"'
      echo 'EndSection'
      echo
    done
    echo 'Section "Monitor"'
    echo "    Identifier \"$(printf '%s' "$CHOSEN" | sanitize_conn)\""
    echo 'EndSection'
    echo
  } > "$CONF_FILE"

  chmod 644 "$CONF_FILE"

  # User notice so it doesn't look "stuck" while persisting overlay
  if declare -f box_hash >/dev/null 2>&1; then
    box_hash
    box_center "Saving 10-monitor.conf to persistent storage — please wait (can take ~10–30s)"
    box_hash
  else
    echo "Saving 10-monitor.conf to persistent storage — please wait (can take ~10–30s)"
  fi

  # Time the save for diagnostics
  t0="$(date +%s)"
  batocera-save-overlay >>"$LOG_FILE" 2>&1 || {
    echo "WARN: batocera-save-overlay failed; changes may not persist after reboot." >>"$LOG_FILE"
  }
  t1="$(date +%s)"
  echo "batocera-save-overlay duration: $((t1 - t0))s" >>"$LOG_FILE"

  create_flag_file || true

  echo
  echo "Saved $CONF_FILE"
  echo "  Keep   : $CHOSEN"
  echo "  Ignored: ${OTHERS[*]}"
  echo
}

# ─────────────────────────────────────────────────────────────────────────────
# New output detection & persistence (terminal-only) as a function End!
# ─────────────────────────────────────────────────────────────────────────────


RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[1;34m'
NOCOLOR='\033[0m'


BOOT_RESOLUTION=1
BOOT_RESOLUTION_ES=1
ZFEbHVUE=1


echo
echo "[$(date +"%H:%M:%S")]: BUILD_15KHz_Batocera START" > /userdata/system/logs/BUILD_15KHz_Batocera.log

########################################################################################
#####################        SERGI CLARA "NEW DEDICATION" Start #      #################
########################################################################################

# -------------------- Banner box --------------------
printf "%s\n" "$border"
empty_line
center "- DEDICATION -"
empty_line
center "IN MEMORY OF SERGI CLARA (PSAKHIS)"
empty_line
center "REST IN PEACE"
empty_line
printf "%s\n\n" "$border"

# -------------------- Centered context --------------------
center_plain "This release is dedicated to Sergi Clara (\"psakhis\") of GroovyArcade."
center_plain "He tragically passed away in a bicycle accident on October 9, 2024, at age 44."
center_plain "Sergi made major contributions to the CRT and retro-gaming community—"
center_plain "including GroovyMiSTer, GunCon2, RetroArch, and the wider Groovy/CRT Emudriver ecosystem."
center_plain "We extend our heartfelt condolences to his family and friends,"
center_plain "and we continue our work in his honor."
printf "\n"

center_plain "Selected threads and repositories that highlight his impact:"
printf "\n"

# -------------------- Centered references --------------------
center_plain "• GroovyMiSTer contributions:"
center_plain "  https://forum.arcadecontrols.com/index.php/topic,168163.0/all.html"
printf "\n"

center_plain "• \"CRT Emudriver – Non-emulated compatible games\""
center_plain "  (catalog of modern pixel-art titles that downscale cleanly to 15 kHz):"
center_plain "  https://forum.arcadecontrols.com/index.php/topic,161951.0/all.html"
printf "\n"

center_plain "• emu4crt (Mednafen mod) fork (continuing silmalik's work):"
center_plain "  https://forum.arcadecontrols.com/index.php/topic,155264.0/all.html"
printf "\n"

center_plain "• GunCon2 improvements (Linux & Windows), building on sonik's Windows driver:"
center_plain "  Forum: https://forum.arcadecontrols.com/index.php/topic,166121.0/all.html"
center_plain "  Code:  https://github.com/psakhis/guncon2"
printf "\n"

center_plain "• CRT Emudriver and Vulkan-related updates/discussion:"
center_plain "  https://forum.arcadecontrols.com/index.php/topic,161736.0/all.html"
printf "\n"

center_plain "Press ENTER to continue…"
read -r
echo
########################################################################################
#####################        SERGI CLARA "NEW DEDICATION" End #        #################
########################################################################################

########################################################################################
#####################          New Welcome Message Start               #################
########################################################################################

# --- Batocera CRT Script: Welcome (everything centered) ---

# Fallback ANSI colors if not predefined elsewhere in your script
RED=${RED:-"\033[31m"}
BLUE=${BLUE:-"\033[34m"}
NOCOLOR=${NOCOLOR:-"\033[0m"}

# -------------------- Banner box --------------------
printf "%s\n" "$border"
empty_line
center "BATOCERA CRT SCRIPT — 15 kHz / 25 kHz / 31 kHz for Batocera v42"
empty_line
center "Use at your own risk. The authors are not responsible for damage or data loss."
empty_line
center "Read the official Wiki and Installation Guide (links below)."
empty_line
center "Core team & acknowledgments"
empty_line
center "• ZFEbHVUE — Lead developer & main tester"
center "• Rion — CRT specialist & 15 kHz support"
center "• myzar — NVIDIA driver & compatibility"
center "• jfroco — Early CRT output for Batocera"
center "• rtissera — Enabled 15 kHz patches in Batocera"
center "• Substring — GroovyArcade maintainer (KMS/SDL work)"
center "• Calamity — 15 kHz Linux patches, CRT_EmuDriver, Switchres, GroovyMAME"
center "• D0023R (Doozer) — linux_kernel_15khz maintenance"
center "• dmanlcf — Maintains 15kHz kernel patches for Batocera"
empty_line
center "Hardware compatibility: check the Supported Cards pages (links below)."
empty_line
center "$(printf "%b" "${RED}")IMPORTANT — AMD Sea Islands (GCN 2.x / DCE 8.x):$(printf "%b" "${NOCOLOR}")"
center "Interlace is NOT supported on amdgpu. Use the radeon driver."
empty_line
center "$(printf "%b" "${RED}")NOTE — No 240p theme support:$(printf "%b" "${NOCOLOR}")"
center "320x240 boot resolution themes are not supported."
empty_line
center "If you accept these terms, press ENTER to continue."
empty_line
printf "%s\n" "$border"
printf "\n"

# -------------------- Centered links --------------------
center_plain "Documentation & Links"
center_plain "• Wiki (main):"
center_plain "  https://github.com/ZFEbHVUE/Batocera-CRT-Script/wiki"
printf "\n"

center_plain "• Installation Guide (wired or wireless):"
center_plain "  https://github.com/ZFEbHVUE/Batocera-CRT-Script/blob/main/HowTo_Wired_Or_Wireless_Connection.md"
printf "\n"

center_plain "• Supported AMD dGPUs & APUs:"
center_plain "  https://github.com/ZFEbHVUE/Batocera-CRT-Script/wiki/Supported-AMD-dGPUs-&-APUs"
printf "\n"

center_plain "• Supported NVIDIA (Maxwell, proprietary driver):"
center_plain "  https://github.com/ZFEbHVUE/Batocera-CRT-Script/wiki/Supported-NVIDIA-Maxwell-Cards-%28Proprietary-Driver%29"
printf "\n"

# Long Sea Islands link: center if it fits, otherwise print full left-aligned (no trimming)
center_plain "• AMD Sea Islands (GCN 2.x / DCE 8.x) — use radeon (interlace unsupported on amdgpu):"
sea_link="https://github.com/ZFEbHVUE/Batocera-CRT-Script/wiki/Sea-Islands-(GCN-2.x---DCE-8.x):-Interlace-Unsupported-on-%60amdgpu%60-%E2%80%94-Use-%60radeon%60"

# Guard BOXW in case it's unset; always quote expansions
: "${BOXW:=0}"

if [ "${#sea_link}" -lt "${BOXW}" ]; then
  center_plain "  ${sea_link}"
else
  printf '%s\n' "  ${sea_link}"
fi
printf '\n'


# -------------------- Prompt (centered, no newline before read) --------------------
msg="PRESS ${BLUE}ENTER${NOCOLOR} TO START "
plain="$(printf "%b" "$msg" | sed 's/\x1B\[[0-9;]*[A-Za-z]//g')"
pad=$(( (BOXW - ${#plain}) / 2 ))
printf "%*s%b" "$pad" "" "$msg"
read -r
echo

########################################################################################
#####################            New Welcome Message End               #################
########################################################################################


# Read Batocera version (fallback to "unknown" if the command is missing)
version_Batocera="$(batocera-es-swissknife --version 2>/dev/null || echo unknown)"
echo "Version batocera = ${version_Batocera}" >> /userdata/system/logs/BUILD_15KHz_Batocera.log

case "${version_Batocera}" in
  42*)
    echo "Version 42"
    Version_of_batocera="v42"
    VERSION_BATOCERA_NUM=42
    ;;
  *)
    echo "Unknown or unsupported Batocera version: ${version_Batocera}"
    Version_of_batocera="unknown"
    VERSION_BATOCERA_NUM=0
    ;;
esac

# (Optional) temporary compatibility for any stray references to the old misspelled var.
# You can remove this after you’re sure nothing reads "verion".
verion="${VERSION_BATOCERA_NUM}"


printf "%s\n" "$border"
empty_line
center "Discrete Graphics Card (dGPU) / Accelerated Processing Unit (APU)"
empty_line
printf "%s\n" "$border"

j=0
for p in /sys/class/drm/card? ; do
	id=$(basename "$(readlink -f "$p/device")")
	temp=$(lspci -mms "$id" | cut -d '"' -f4,6)
	name_card[$j]="$temp"
	j=$((j + 1))
done

box_empty
for var in "${!name_card[@]}"; do
  echo "	$((var+1)) : ${name_card[$var]}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
done

if [[ "$var" -gt 0 ]] ; then
  box_hash
  box_center "Make your choice for graphic card"
  box_hash
  center_plain_log "Select option 1 to $((var+1)):"
  read card_choice
  while [[ ! ${card_choice} =~ ^[1-$((var+1))]$ ]] && [[ "$card_choice" != "" ]] ; do
    center_plain_log "Select option 1 to $((var+1)):"
    read card_choice
  done
  selected_card=${name_card[$card_choice-1]}
else
  selected_card=${temp}
fi

###############################################################
##    TYPE OF GRAPHIC CARD
###############################################################
Drivers_Nvidia_CHOICE="NONE"

case $selected_card in
	*[Nn][Vv][Ii][Dd][Ii][Aa]*)

		TYPE_OF_CARD="NVIDIA"

		if [ ! -f "/userdata/system/logs/TYPE_OF_CARD_DRIVERS.info" ]; then
			touch /userdata/system/logs/TYPE_OF_CARD_DRIVERS.info
			echo "NVIDIA" >> /userdata/system/logs/TYPE_OF_CARD_DRIVERS.info
		else
			rm /userdata/system/logs/TYPE_OF_CARD_DRIVERS.info
			touch /userdata/system/logs/TYPE_OF_CARD_DRIVERS.info
			echo "NVIDIA" >> /userdata/system/logs/TYPE_OF_CARD_DRIVERS.info
		fi

		box_hash
		box_center "YOUR VIDEO CARD IS ${GREEN}NVIDIA${NOCOLOR}"
		box_hash

		box_hash
		box_center "Do you want Nvidia_Drivers or NOUVEAU"
		box_hash

		declare -a Nvidia_drivers_type=( "Nvidia_Drivers" "NOUVEAU" )
		for var in "${!Nvidia_drivers_type[@]}"; do
      echo "			$((var+1)) : ${Nvidia_drivers_type[$var]}"
    done

		box_hash
		box_center "Make your choice"
		box_hash

		center_plain_log "Select option 1 to $((var+1)):"
		read choice_Drivers_Nvidia
		while [[ ! ${choice_Drivers_Nvidia} =~ ^[1-$((var+1))]$ ]] && [[ "$choice_Drivers_Nvidia" = "" ]] ; do
			center_plain_log "Select option 1 to $((var+1)):"
			read choice_Drivers_Nvidia
		done

		Drivers_Nvidia_CHOICE=${Nvidia_drivers_type[$choice_Drivers_Nvidia-1]}
		box_center "your choice is :  ${GREEN}$Drivers_Nvidia_CHOICE${NOCOLOR}"
		echo "$Drivers_Nvidia_CHOICE" >> /userdata/system/logs/TYPE_OF_CARD_DRIVERS.info

		if [ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]; then
			box_hash
			box_center "Nvidia drivers version selector"
			box_hash

			declare -a Name_Nvidia_drivers_version=( "true" "legacy470" "legacy390" "legacy340" )
			for var in "${!Name_Nvidia_drivers_version[@]}"; do
        echo "			$((var+1)) : ${Name_Nvidia_drivers_version[$var]}"
      done

			box_hash
			box_center "Make your choice"
			box_hash

			center_plain_log "Select option 1 to $((var+1)):"
			read choice_Name_Drivers_Nvidia
			while [[ ! ${choice_Name_Drivers_Nvidia} =~ ^[1-$((var+1))]$ ]] && [[ "$choice_Name_Drivers_Nvidia" = "" ]] ; do
				center_plain_log "Select option 1 to $((var+1)):"
				read choice_Name_Drivers_Nvidia
			done

			Drivers_Name_Nvidia_CHOICE=${Name_Nvidia_drivers_version[$choice_Name_Drivers_Nvidia-1]}
			box_center "your choice is :  ${GREEN}$Drivers_Name_Nvidia_CHOICE${NOCOLOR}"
		fi
	;;

	*[Ii][Nn][Tt][Ee][Ll]*)
		TYPE_OF_CARD="INTEL"

		box_hash
		box_center "YOUR VIDEO CARD IS ${GREEN}INTEL${NOCOLOR}"
		box_hash

		if [ ! -f "/userdata/system/logs/TYPE_OF_CARD_DRIVERS.info" ]; then
			touch /userdata/system/logs/TYPE_OF_CARD_DRIVERS.info
			echo "INTEL" >> /userdata/system/logs/TYPE_OF_CARD_DRIVERS.info
		else
			rm /userdata/system/logs/TYPE_OF_CARD_DRIVERS.info
			touch /userdata/system/logs/TYPE_OF_CARD_DRIVERS.info
			echo "INTEL" >> /userdata/system/logs/TYPE_OF_CARD_DRIVERS.info
		fi

	;;

	*[Aa][Mm][Dd]* | *[Aa][Tt][Ii]*)
		TYPE_OF_CARD="AMD/ATI"

		if [ ! -f "/userdata/system/logs/TYPE_OF_CARD_DRIVERS.info" ]; then
			touch /userdata/system/logs/TYPE_OF_CARD_DRIVERS.info
			echo "AMD/ATI" >> /userdata/system/logs/TYPE_OF_CARD_DRIVERS.info
		else
			rm /userdata/system/logs/TYPE_OF_CARD_DRIVERS.info
			echo "AMD/ATI" >> /userdata/system/logs/TYPE_OF_CARD_DRIVERS.info
			echo "AMD/ATI" >> /userdata/system/logs/TYPE_OF_CARD_DRIVERS.info
		fi

		box_hash
		box_center "YOUR VIDEO CARD IS ${GREEN}AMD/ATI${NOCOLOR}"
		box_hash

# --- R9 380 special handling: ensure amdgpu.dc=0 is in syslinux.cfg files ---
if echo "$selected_card" | grep -qi 'r9' && echo "$selected_card" | grep -q '380'; then
  R9_380="YES"

  box_hash
  box_center "You have an ${GREEN}ATI R9 380/380x${NOCOLOR}"
  box_hash

  # Candidate syslinux locations (some may not exist on a given system)
  SYS_CAND="/boot/EFI/syslinux.cfg /boot/EFI/BOOT/syslinux.cfg /boot/boot/syslinux.cfg /boot/boot/syslinux/syslinux.cfg"

  # Check only files that actually exist
  need_fix=0
  found_any=0
  for f in $SYS_CAND; do
    [ -f "$f" ] || continue
    found_any=1
    if ! grep -q 'amdgpu\.dc=0' "$f"; then
      need_fix=1
      break
    fi
  done

  if [ "$found_any" -eq 1 ] && [ "$need_fix" -eq 0 ]; then
    box_hash
    box_center "${GREEN}This discrete dGPU/APU is ready for 15KHz${NOCOLOR}"
    box_hash
	prompt_centered_tty "PRESS ${BLUE}ENTER${NOCOLOR} TO CONTINUE TO SCANNING OUTPUTS. THIS MAY TAKE UP TO 20-30 SECONDS. PLEASE WAIT)"
  else
    box_hash
    if [ "$found_any" -eq 0 ]; then
      box_center "${RED}No syslinux.cfg files found to update${NOCOLOR}"
    else
      box_center "${RED}This discrete GPU (dGPU) is not ready for 15KHz${NOCOLOR}"
      box_center "Need to add amdgpu.dc=0 to syslinux.cfg"
    fi
    box_hash

    prompt_centered_tty "PRESS ${BLUE}ENTER${NOCOLOR} TO UPDATE syslinux.cfg"

    mount -o remount,rw /boot 2>/dev/null || true

    for f in $SYS_CAND; do
      [ -f "$f" ] || continue

      # Backups
      cp -f "$f" "${f}.bak" 2>/dev/null || true
      if [ ! -f "${f}.initial" ]; then
        cp -f "$f" "${f}.initial" 2>/dev/null || true
      fi

      # Skip if already present
      if grep -q 'amdgpu\.dc=0' "$f"; then
        chmod 755 "$f" 2>/dev/null || true
        continue
      fi

      # Edit in place: insert after 'mitigations=off' if present; else append to APPEND line
      tmpf="${f}.patched"
      if grep -q 'mitigations=off' "$f"; then
        sed 's/mitigations=off/& amdgpu.dc=0 /' "$f" > "$tmpf"
      else
        # Append to APPEND line(s)
        sed 's/^\([[:space:]]*APPEND[[:space:]].*\)$/\1 amdgpu.dc=0 /' "$f" > "$tmpf"
      fi

      mv -f "$tmpf" "$f"
      chmod 755 "$f" 2>/dev/null || true
      echo "Updated $f (added amdgpu.dc=0)" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
    done

    box_hash
    box_center "ENTER to reboot and finalize 15KHz setup for this card"
    box_hash
    prompt_centered_tty "PRESS ${BLUE}ENTER${NOCOLOR} TO REBOOT"
    reboot
    exit
  fi

  # EmulationStation settings for R9 (keep inside then-branch)
  source_file="/userdata/system/Batocera-CRT-Script/System_configs/R9/v42/es_settings.cfg"
  destination_file="/userdata/system/configs/emulationstation/es_settings.cfg"

  if [ ! -f "$destination_file" ]; then
    cp "$source_file" "$destination_file"
    chmod 0644 "$destination_file"
  else
    if ! grep -q '<string name="GameTransitionStyle" value="instant" />' "$destination_file"; then
      cp "$source_file" "$destination_file"
      chmod 0644 "$destination_file"
    fi
  fi

else
  R9_380="NO"
  box_hash
  box_center "${GREEN}This card is ready for 15KHz${NOCOLOR}"
  box_hash
  prompt_centered_tty "PRESS ${BLUE}ENTER${NOCOLOR} TO CONTINUE"
fi

########################################################################################
# --- AMD IP discovery pre-scan (multi-GPU) — build per-card envs start ---        #####
########################################################################################
# --- AMD IP discovery pre-scan (multi-GPU) — build per-card envs ---
# Purpose:
#   - Walk every AMD GPU under /sys/class/drm/card*
#   - Read amdgpu_ip_info (IP discovery) to detect DISPLAY_ENGINE (DCN/DCE) + version
#   - Apply policy: DCN => AMD_IS_APU=1 (runtime truth), else legacy PCI list / fallbacks
#   - Write /tmp/crt-detect/cardN.env per card (used later when a connector is chosen)
#
# Inputs:  kernel debugfs (amdgpu_ip_info), lspci (optional), PCI_LIST (legacy APU table)
# Outputs: /tmp/crt-detect/cardN.env with: AMD_CARD_INDEX, AMD_PCI_ADDR, DISPLAY_ENGINE,
#          DISPLAY_VERSION, AMD_IS_APU, APU_REASON, etc.
# Notes:   No card is “selected” yet; this is only inventory. Binding happens in Part 2.

# Multi-GPU pre-scan: build /tmp/crt-detect/cardN.env for each AMD GPU.
PCI_LIST="/userdata/system/Batocera-CRT-Script/Cards_detection/list_detection_amd_apu.txt"
OUTDIR="/tmp/crt-detect"
mkdir -p "$OUTDIR"
rm -f "$OUTDIR"/card*.env 2>/dev/null || true   # <-- clear stale envs

# Best-effort mount of debugfs (fine if it fails)
mount | grep -q " on /sys/kernel/debug type debugfs " || mount -t debugfs debugfs /sys/kernel/debug 2>/dev/null || true
if mount | grep -q " on /sys/kernel/debug type debugfs "; then
  echo "debugfs mounted." >> /userdata/system/logs/BUILD_15KHz_Batocera.log
else
  echo "debugfs NOT mounted (DISPLAY_ENGINE may be NONE)." >> /userdata/system/logs/BUILD_15KHz_Batocera.log
fi
shopt -s nullglob

# --- Robust engine parser: read DCN/DCE + version from several debugfs files or dmesg ---
parse_display_engine_from_text() {
  # echo text | parse_display_engine_from_text -> sets PARSED_ENGINE, PARSED_VERSION
  local line
  PARSED_ENGINE=""
  PARSED_VERSION=""
  # prefer DCN if present
  while IFS= read -r line; do
    # Normalize separators to spaces
    line="$(printf '%s' "$line" | tr '_' ' ' )"
    if printf '%s\n' "$line" | grep -qiE '(dcn|display[[:space:]_]*core)'; then
      # collect up to three numbers in order
      ver="$(printf '%s\n' "$line" | awk 'BEGIN{IGNORECASE=1}
        {
          n=split($0,a,/[^0-9]+/); c=0; out="";
          for(i=1;i<=n && c<3;i++){
            if(a[i]~/^[0-9]+$/){ c++; out=(out==""?a[i]:out"."a[i]); }
          }
          if(c>0){ print out; exit }
        }')"
      PARSED_ENGINE="DCN"
      PARSED_VERSION="$ver"
      [ -n "$PARSED_VERSION" ] || PARSED_VERSION=""
      return 0
    fi
  done
  # Try DCE as a second pass
  while IFS= read -r line; do
    line="$(printf '%s' "$line" | tr '_' ' ' )"
    if printf '%s\n' "$line" | grep -qi 'dce'; then
      ver="$(printf '%s\n' "$line" | awk 'BEGIN{IGNORECASE=1}
        {
          n=split($0,a,/[^0-9]+/); c=0; out="";
          for(i=1;i<=n && c<3;i++){
            if(a[i]~/^[0-9]+$/){ c++; out=(out==""?a[i]:out"."a[i]); }
          }
          if(c>0){ print out; exit }
        }')"
      PARSED_ENGINE="DCE"
      PARSED_VERSION="$ver"
      [ -n "$PARSED_VERSION" ] || PARSED_VERSION=""
      return 0
    fi
  done
  
  # Heuristic fallback via lspci name (engine only, no version)
  if [ -z "$OUT_ENGINE" ]; then
    local NAME_LINE=""
    if command -v lspci >/dev/null 2>&1; then
      # Prefer a known PCI address if exported; otherwise, take the first AMD VGA/Display controller line.
      local _pci="${AMD_PCI_ADDR:-${PCI_ADDR:-}}"
      if [ -n "$_pci" ]; then
        NAME_LINE="$(lspci -s "${_pci#0000:}" -nn 2>/dev/null || true)"
      else
        NAME_LINE="$(lspci -nn 2>/dev/null | grep -iE 'VGA.*AMD|Display.*AMD' | head -n1 || true)"
      fi
    fi
	    # Normalize
    NAME_LINE="$(printf '%s' "$NAME_LINE" | tr '[:upper:]' '[:lower:]')"
    if printf '%s' "$NAME_LINE" | grep -qE '(navi|rdna|sienna|phoenix|rembrandt|vangogh|aero|merce|navi [0-9]+)'; then
      OUT_ENGINE="DCN"
      OUT_VERSION=""
      echo "Engine detect: heuristic => DCN (from lspci name: $NAME_LINE)" >> /userdata/system/logs/BUILD_15KHz_Batocera.log
    elif printf '%s' "$NAME_LINE" | grep -qE '(polaris|tonga|hawaii|bonaire|pitcairn|kabini|kaveri|carrizo|stoney|cape verde|curacao|oland|tahiti|verde|gfx7|gfx8)'; then
      OUT_ENGINE="DCE"
      OUT_VERSION=""
      echo "Engine detect: heuristic => DCE (from lspci name: $NAME_LINE)" >> /userdata/system/logs/BUILD_15KHz_Batocera.log
    fi
  fi
return 1
}

read_engine_anywhere() {
  # args: card index -> sets OUT_ENGINE, OUT_VERSION
  local IDX="$1"
  OUT_ENGINE=""; OUT_VERSION=""

  # Candidate files in priority order
  local f
  echo "Engine detect: probing debugfs files for card${IDX}" >> /userdata/system/logs/BUILD_15KHz_Batocera.log
  for f in \
    "/sys/kernel/debug/dri/${IDX}/amdgpu_ip_info" \
    "/sys/kernel/debug/dri/${IDX}/amdgpu_ip_discovery" \
    "/sys/kernel/debug/dri/${IDX}/amdgpu_dm_info" \
    "/sys/kernel/debug/dri/${IDX}/amdgpu_firmware_info" \
    "/sys/kernel/debug/dri/${IDX}/amdgpu_vbios_info" \
    "/sys/kernel/debug/dri/${IDX}/amdgpu_pm_info"
  do
    if [ -r "$f" ]; then
      echo "  + exists: $f ($(stat -c %s "$f" 2>/dev/null || echo ? ) bytes)" >> /userdata/system/logs/BUILD_15KHz_Batocera.log
      head -n 20 "$f" 2>/dev/null | sed "s/^/    | /" >> /userdata/system/logs/BUILD_15KHz_Batocera.log
      if parse_display_engine_from_text < "$f"; then
		echo "  -> parsed engine from: $f => engine=${PARSED_ENGINE:-unknown} version=${PARSED_VERSION:-unknown}" >> /userdata/system/logs/BUILD_15KHz_Batocera.log
        OUT_ENGINE="$PARSED_ENGINE"
        OUT_VERSION="$PARSED_VERSION"
        [ -n "$OUT_ENGINE" ] && return 0
      fi
    fi
  done

  # dmesg fallback (may require root; ignore errors)
  if dmesg 2>/dev/null | grep -qiE '(dcn|dce|display core|display controller)'; then
    echo "Engine detect: trying dmesg parse (card${IDX})" >> /userdata/system/logs/BUILD_15KHz_Batocera.log
    if dmesg 2>/dev/null | parse_display_engine_from_text; then
	  echo "  -> parsed engine from: dmesg => engine=${PARSED_ENGINE:-unknown} version=${PARSED_VERSION:-unknown}" >> /userdata/system/logs/BUILD_15KHz_Batocera.log
      OUT_ENGINE="$PARSED_ENGINE"
      OUT_VERSION="$PARSED_VERSION"
      [ -n "$OUT_ENGINE" ] && return 0
    fi
  fi
  
  # Heuristic fallback via lspci name (engine only, no version)
  if [ -z "$OUT_ENGINE" ]; then
    local NAME_LINE=""
    if command -v lspci >/dev/null 2>&1; then
      # Resolve this card's PCI addr from sysfs; fall back to first AMD VGA/Display controller
      local _pci=""
      if [ -e "/sys/class/drm/card${IDX}/device" ]; then
        _pci="$(basename "$(readlink -f "/sys/class/drm/card${IDX}/device")")"
      fi
      if [ -n "$_pci" ]; then
        NAME_LINE="$(lspci -s "${_pci#0000:}" -nn 2>/dev/null || true)"
      else
        NAME_LINE="$(lspci -nn 2>/dev/null | grep -iE 'VGA.*AMD|Display.*AMD' | head -n1 || true)"
      fi
    fi
    # Normalize
    NAME_LINE="$(printf '%s' "$NAME_LINE" | tr '[:upper:]' '[:lower:]')"
    if printf '%s' "$NAME_LINE" | grep -qE '(navi|rdna|sienna|phoenix|rembrandt|vangogh|aero|merce|navi [0-9]+)'; then
      OUT_ENGINE="DCN"
      OUT_VERSION=""
      echo "Engine detect: heuristic => DCN (from lspci name: $NAME_LINE)" >> /userdata/system/logs/BUILD_15KHz_Batocera.log
    elif printf '%s' "$NAME_LINE" | grep -qE '(polaris|tonga|hawaii|bonaire|pitcairn|kabini|kaveri|carrizo|stoney|cape verde|curacao|oland|tahiti|verde|gfx7|gfx8)'; then
      OUT_ENGINE="DCE"
      OUT_VERSION=""
      echo "Engine detect: heuristic => DCE (from lspci name: $NAME_LINE)" >> /userdata/system/logs/BUILD_15KHz_Batocera.log
    fi
  fi
  # If heuristic or any method set OUT_ENGINE, treat as success
  if [ -n "${OUT_ENGINE:-}" ]; then return 0; fi
return 1
}

# Map CHIP_* family (from list_detection_amd_apu.txt) to display engine
infer_engine_from_chip() {
  # args: CHIP token (e.g., CHIP_TONGA) -> echoes DCN or DCE and returns 0 if known, else 1
  # Source signals: Linux amdgpu CHIP_* enums + family groupings cross-checked vs. AMD GPU lists.
  local chip="$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')"

  case "$chip" in
    ########################################################################
    # DCN families (APUs and dGPUs with Display Core Next)
    # RDNA / RDNA2 / RDNA3 dGPU families + modern APUs
    ########################################################################
    CHIP_NAVI*|CHIP_SIENNA_CICHLID|CHIP_NAVY_FLOUNDER|CHIP_DIMGREY_CAVEFISH|CHIP_BEIGE_GOBY|\
CHIP_ARCTURUS|CHIP_ALDEBARAN|\
CHIP_RAVEN|CHIP_RAVEN2|CHIP_RENOIR|CHIP_GREEN_SARDINE|CHIP_CEZANNE|CHIP_YELLOW_CARP|\
CHIP_VANGOGH|CHIP_MENDOCINO|CHIP_PHOENIX|CHIP_PHOENIX2|CHIP_RAPHAEL|CHIP_STRIX*|CHIP_HAWK*)
      echo DCN; return 0;;

    ########################################################################
    # DCE families (pre-DCN display engine generations)
    # GCN dGPUs and older APUs; includes Vega dGPU (DCE-12 class)
    ########################################################################
    CHIP_VEGA*|CHIP_VEGAM|CHIP_FIJI|\
CHIP_TONGA|CHIP_POLARIS*|CHIP_HAWAII|CHIP_BONAIRE|\
CHIP_TAHITI|CHIP_PITCAIRN|CHIP_VERDE|CHIP_OLAND|CHIP_TOPAZ|\
CHIP_KABINI|CHIP_KAVERI|CHIP_CARRIZO|CHIP_STONEY|CHIP_MULLINS)
      echo DCE; return 0;;

    ########################################################################
    # Unknown/older (leave to other detection paths)
    ########################################################################
    *)
      return 1;;
  esac
}

# Lookup PCI id in list_detection_amd_apu.txt and infer DISPLAY_ENGINE/AMD_IS_APU if possible
infer_from_pci_list() {
  # args: vendor (hex w/o 0x), device (hex w/o 0x), path-to-list
  local ven="$1" dev="$2" list="$3"
  [ -r "$list" ] || return 1
  # tolerate junk before brace and case-insensitive hex
  local line
  line="$(grep -iE "[^0-9A-Fa-f\{]*\{0x${ven},[[:space:]]*0x${dev}," "$list" | head -n1)"
  [ -n "$line" ] || return 1

  # Detect APU flag
  if printf '%s' "$line" | grep -q 'AMD_IS_APU'; then
    echo "PCI list: AMD_IS_APU flag present for ${ven}:${dev}" >> /userdata/system/logs/BUILD_15KHz_Batocera.log
    AMD_IS_APU=1
    APU_REASON="legacy list (PCI table)"
  fi

  # Extract CHIP_* token
  local chip; chip="$(printf '%s' "$line" | sed -nE 's/.*(CHIP_[A-Za-z0-9_]+).*/\1/p' | head -n1)"
  if [ -n "$chip" ]; then
    local eng; eng="$(infer_engine_from_chip "$chip" || true)"
    if [ -n "$eng" ] && [ "${DISPLAY_ENGINE:-NONE}" = "NONE" ]; then
      DISPLAY_ENGINE="$eng"
      DISPLAY_VERSION=""
      echo "PCI list: inferred engine ${eng} from ${chip} for ${ven}:${dev}" >> /userdata/system/logs/BUILD_15KHz_Batocera.log
      return 0
    fi
  fi
  return 0
}




APU_NAMES_RE='raven|raven ridge|raven2|picasso|dali|pollock|renoir|lucienne|cezanne|barcelo|van[[:space:]]*gogh|yellow[[:space:]]*carp|rembrandt|phoenix( 2)?|hawk[[:space:]]*point|strix[[:space:]]*point|mendocino'

read_triplet_from_ipinfo() {
  local f="$1" re="$2"
  awk 'BEGIN{IGNORECASE=1}
       $0 ~ /'"$re"'/ {
         n=split($0,a,/[^0-9]+/); c=0;
         for(i=1;i<=n;i++){ if(a[i]~/^[0-9]+$/){v[++c]=a[i]; if(c==3) break} }
         if(c==3){ print v[1]"."v[2]"."v[3]; exit 0 }
       }' "$f" 2>/dev/null || true
}

is_amd_card() {
  [[ -e "$1/device/vendor" ]] && [[ "$(tr '[:upper:]' '[:lower:]' < "$1/device/vendor")" == "0x1002" ]]
}

process_card_prescan() {
  local CARD="$1"
  local IDX="${CARD##*/card}"
  local DEV="$CARD/device"
  local PCI_ADDR; PCI_ADDR="$(basename "$(readlink -f "$DEV")")"
  local VEN DEVHEX; VEN="$(<"$DEV/vendor")"; DEVHEX="$(<"$DEV/device")"
  VEN="${VEN#0x}"; DEVHEX="${DEVHEX#0x}"

  local LSPCI_LINE="AMD GPU at ${PCI_ADDR}"
  if command -v lspci >/dev/null 2>&1; then
    LSPCI_LINE=$(lspci -s "${PCI_ADDR#0000:}" -nn 2>/dev/null | sed 's/^[^:]*: //') || true
  fi

  local IPINFO="/sys/kernel/debug/dri/${IDX}/amdgpu_ip_info"
  local AMD_IS_APU=0 APU_REASON=""
  local DISPLAY_ENGINE="NONE" DISPLAY_VERSION=""

  
  # Legacy table (older APUs)
  if [[ -r "$PCI_LIST" ]] && grep -iq "{0x$VEN, 0x$DEVHEX, .*AMD_IS_APU}" "$PCI_LIST"; then
    AMD_IS_APU=1; APU_REASON="legacy list (PCI table)"
  fi

  # Display engine from multiple sources; do NOT equate DCN with APU.
  if read_engine_anywhere "$IDX"; then
    echo "Engine detect: read_engine_anywhere OK for card${IDX}: ${OUT_ENGINE} ${OUT_VERSION}" >> /userdata/system/logs/BUILD_15KHz_Batocera.log
    DISPLAY_ENGINE="$OUT_ENGINE"
    DISPLAY_VERSION="$OUT_VERSION"
  else
    echo "Engine detect: FAILED for card${IDX} — leaving NONE (check debugfs + grep patterns)" >> /userdata/system/logs/BUILD_15KHz_Batocera.log
    DISPLAY_ENGINE="NONE"
    DISPLAY_VERSION=""
  fi

  # APU detection stays independent from DCN/DCE:
  if [[ $AMD_IS_APU -ne 1 ]]; then
    if [[ -n "$LSPCI_LINE" ]] && echo "$LSPCI_LINE" | grep -qiE "$APU_NAMES_RE"; then
      AMD_IS_APU=1; APU_REASON="lspci APU codename"
    else
      local DRIVER VRAM_TOT="" GTT_TOT=""
      DRIVER="$(basename "$(readlink -f "$DEV/driver" 2>/dev/null)" 2>/dev/null || true)"
      if [ "$DRIVER" = "amdgpu" ]; then
        [ -r "$DEV/mem_info_vram_total" ] && VRAM_TOT="$(cat "$DEV/mem_info_vram_total")"
        [ -r "$DEV/mem_info_gtt_total"  ] && GTT_TOT="$(cat "$DEV/mem_info_gtt_total")"
      fi
      if [[ "$VRAM_TOT" =~ ^[0-9]+$ && "$GTT_TOT" =~ ^[0-9]+$ ]] && \
         (( VRAM_TOT < 900000000 )) && (( GTT_TOT >= 256*1024*1024 )); then
        AMD_IS_APU=1; APU_REASON="UMA heuristic (small VRAM + large GTT)"
      else
        AMD_IS_APU=0; APU_REASON="${APU_REASON:-default (discrete or unknown)}"
      fi
    fi
  fi
# Save per-card env (banner will be shown later when we know the chosen connector)
  
  # If engine is still NONE, try inferring from PCI list (legacy table)
  if [ "${DISPLAY_ENGINE:-NONE}" = "NONE" ] && [ -r "$PCI_LIST" ]; then
    infer_from_pci_list "${VEN}" "${DEVHEX}" "$PCI_LIST" || true
  fi

  # Caller safety net: if DISPLAY_ENGINE is still NONE, infer from lspci name
  if [ "${DISPLAY_ENGINE:-NONE}" = "NONE" ] && command -v lspci >/dev/null 2>&1; then
    name="$(lspci -s "${PCI_ADDR#0000:}" -nn 2>/dev/null | tr '[:upper:]' '[:lower:]')"
    if printf '%s' "$name" | grep -qE '(navi|rdna|sienna|navy[ _-]flounder|dimgrey[ _-]cavefish|beige[ _-]goby|arcturus|aldebaran|raven|renoir|cezanne|vangogh|yellow[ _-]carp|phoenix|raphael|strix)'; then
      DISPLAY_ENGINE="DCN"; DISPLAY_VERSION=""
      echo "Engine detect: caller safety net => DCN (from lspci name: $name)" >> /userdata/system/logs/BUILD_15KHz_Batocera.log
    elif printf '%s' "$name" | grep -qE '(polaris|tonga|hawaii|bonaire|pitcairn|tahiti|verde|oland|fiji|topaz|kabini|kaveri|carrizo|stoney|mullins)'; then
      DISPLAY_ENGINE="DCE"; DISPLAY_VERSION=""
      echo "Engine detect: caller safety net => DCE (from lspci name: $name)" >> /userdata/system/logs/BUILD_15KHz_Batocera.log
    fi
  fi
cat > "/tmp/crt-detect/card${IDX}.env" <<EOF
AMD_CARD_INDEX=${IDX}
AMD_PCI_ADDR=${PCI_ADDR}
AMD_VENDOR=0x${VEN}
AMD_DEVICE=0x${DEVHEX}
LSPCI_LINE=$(printf '%q' "$LSPCI_LINE")
DISPLAY_ENGINE=${DISPLAY_ENGINE}
DISPLAY_VERSION=${DISPLAY_VERSION}
AMD_IS_APU=${AMD_IS_APU}
APU_REASON=$(printf '%q' "$APU_REASON")
EOF
}

found_any=0
for CARD in /sys/class/drm/card*; do
  is_amd_card "$CARD" || continue
  found_any=1
  process_card_prescan "$CARD"
done

if [[ $found_any -eq 0 ]]; then
  echo "!!!! BE CAREFUL: no AMD GPU detected !!!!"
  # Surrounding case/esac continues; later logic will abort if needed.
fi
########################################################################################
# --- AMD IP discovery pre-scan (multi-GPU) — build per-card envs END ---          #####
########################################################################################
	;;
	*)
		# Centered + logged unknown-card banner, then exit as before
		box_hash
		box_center "${RED}YOUR CARD IS UNKNOWN${NOCOLOR}"
		box_center "Please report the detected PCI ID / lspci string above."
		box_hash
		exit 1
	;;
esac

# Final selection line — pick ONE of the two styles below:

# (A) Keep original plain log line (not centered)
# echo "	Selected card = ${CHOSEN:-$selected_card}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log

# (B) Centered + logged (plain line, not boxed)
center_plain_log "Selected card = ${CHOSEN:-$selected_card}"


# Run output detection now (after GPU preflight)
output_detection_and_persist


# The new detector already picked a connector and wrote 10-monitor.conf.
# We just confirm & log it here, keeping the old variable name for compatibility.

# Safety: make sure CHOSEN is set (the detector sets it globally)
if [ -z "${CHOSEN:-}" ]; then
  echo "ERROR: No connector selected (CHOSEN is empty). Did you call output_detection_and_persist earlier?"
  exit 1
fi

# Keep downstream compatibility with older code that used $video_output
video_output="${KERNEL_CONN_NAME:-$CHOSEN}"   # DRM name for syslinux [card_output]
video_output_xrandr="${video_output_xrandr:-$CHOSEN}"  # Xorg/xrandr name for X11 bits

########################################################################################
# --- Bind selected connector to owning AMD card — load env + banner START ---     #####
########################################################################################
# --- Bind selected connector to owning AMD card — load env + banner ---
# Purpose:
#   - Map the chosen connector (e.g., DP-1/HDMI-A-1) to its owning cardN
#   - Source /tmp/crt-detect/cardN.env from Part 1 (DISPLAY_ENGINE, AMD_IS_APU, etc.)
#   - Show the APU banner and log a one-liner with connector -> card mapping
#
# Inputs:  video_output (the connector chosen by the user/detector), cardN.env files
# Outputs: Exports AMD_IS_APU, DISPLAY_ENGINE, DISPLAY_VERSION, AMD_CARD_INDEX, AMD_PCI_ADDR
# Downstream: interlace parity (IFE) and EDID generation will key off DISPLAY_ENGINE.
# Map a connector like "VGA-0" / "HDMI-0" / "HDMI-A-1" / "DVI-0" / "DP-1" / "DisplayPort-1"
# to its owning AMD card index (N), tolerating xrandr <-> sysfs naming differences.
# Only binds to cards we prescanned (i.e., with /tmp/crt-detect/cardN.env).
get_card_index_for_connector() {
  local want_raw="$1" base card_part conn_part idx

  # --- helpers --------------------------------------------------------------

  # normalize a connector NAME -> TYPE and INDEX, plus a "TYPE-INDEX" token
  # Examples:
  #   HDMI-A-1   -> TYPE=HDMI  INDEX=1  TOKEN=HDMI-1
  #   HDMI-0     -> TYPE=HDMI  INDEX=0  TOKEN=HDMI-0
  #   DVI-D-1    -> TYPE=DVI   INDEX=1  TOKEN=DVI-1
  #   DisplayPort-1 -> TYPE=DP INDEX=1  TOKEN=DP-1
  #   VGA-1      -> TYPE=VGA   INDEX=1  TOKEN=VGA-1
  normalize_name() {
    # in: $1 -> sets: N_TYPE, N_INDEX, N_TOKEN
    local n="$(echo "$1" | tr '[:lower:]' '[:upper:]')"

    # Canonicalize type keywords
    n="${n/EDP-/EDP-}"
    n="${n/LVDS-/LVDS-}"
    n="${n/DISPLAYPORT-/DP-}"   # DisplayPort -> DP

    # Strip lettered subtypes to core TYPE (HDMI-A -> HDMI, DVI-D -> DVI, etc.)
    n="$(echo "$n" | sed -E 's/^(HDMI|DVI|DP|VGA|EDP|LVDS)(-[A-Z]+)*/\1-/')"

    # Extract TYPE (before first dash) and trailing numeric index
    local t i
    t="$(echo "$n" | sed -E 's/^([A-Z]+).*/\1/')"
    i="$(echo "$n" | sed -E 's/.*[^0-9]([0-9]+)$/\1/')"
    # If no index found, assume 0 (rare, but be defensive)
    [[ "$i" =~ ^[0-9]+$ ]] || i=0

    N_TYPE="$t"
    N_INDEX="$i"
    N_TOKEN="${t}-${i}"
  }

  # generate candidate sysfs-style names to try for TYPE/INDEX
  # outputs space-separated list via echo
  gen_candidates_for() {
    local t="$1" i="$2" out=()

    case "$t" in
      HDMI)
        # sysfs usually uses HDMI-A-<n>
        out+=("HDMI-${i}" "HDMI-A-${i}")
        ;;
      DVI)
        # sysfs can expose DVI-D-<n> or DVI-I-<n>
        out+=("DVI-${i}" "DVI-D-${i}" "DVI-I-${i}")
        ;;
      DP)
        out+=("DP-${i}")
        ;;
      VGA)
        out+=("VGA-${i}")
        ;;
      EDP)
        out+=("eDP-${i}" "EDP-${i}")
        ;;
      LVDS)
        out+=("LVDS-${i}")
        ;;
      *)
        out+=("${t}-${i}")
        ;;
    esac

    # also try a common index skew (0 <-> 1) variants
    if [[ "$i" -eq 0 || "$i" -eq 1 ]]; then
      local j=$((1 - i))
      case "$t" in
        HDMI) out+=("HDMI-${j}" "HDMI-A-${j}") ;;
        DVI)  out+=("DVI-${j}" "DVI-D-${j}" "DVI-I-${j}") ;;
        DP)   out+=("DP-${j}") ;;
        VGA)  out+=("VGA-${j}") ;;
        EDP)  out+=("eDP-${j}" "EDP-${j}") ;;
        LVDS) out+=("LVDS-${j}") ;;
      esac
    fi

    echo "${out[*]}"
  }

  # normalize requested name and build candidate list
  normalize_name "$want_raw"
  local WANT_TYPE="$N_TYPE" WANT_INDEX="$N_INDEX" WANT_TOKEN="$N_TOKEN"
  # Candidate forms we will accept for the request
  local CANDS=( "$want_raw" "$WANT_TOKEN" $(gen_candidates_for "$WANT_TYPE" "$WANT_INDEX") )

  # --- search across sysfs for a matching AMD connector ---------------------

  for base in /sys/class/drm/card*-*; do
    [ -e "$base" ] || continue
    card_part="${base%%-*}"      # cardN
    conn_part="${base#*-}"       # e.g., HDMI-A-1, DP-1, VGA-1, DVI-D-1
    idx="${card_part#card}"

    # only consider cards we prescanned (i.e., AMD env present)
    [ -r "/tmp/crt-detect/card${idx}.env" ] || continue

    # Build normalized token for the sysfs connector
    normalize_name "$conn_part"
    local SYS_TOKEN="$N_TOKEN"

    # Also include raw sysfs name and its normalized token as things we can match
    local sname="$conn_part"

    # Try exact and tolerant matches
    local cand
    for cand in "${CANDS[@]}"; do
      # Normalize candidate too, to compare tokens
      normalize_name "$cand"
      if [[ "$sname" == "$cand" ]] || [[ "$SYS_TOKEN" == "$N_TOKEN" ]]; then
        echo "$idx"
        return 0
      fi
    done
  done

  # Last resort: if there is exactly one AMD env, bind to it
  local only=() env
  for env in /tmp/crt-detect/card*.env; do
    [ -r "$env" ] || continue
    only+=("$env")
  done
  if [ "${#only[@]}" -eq 1 ]; then
    echo "$(basename "${only[0]}")" | sed -E 's/^card([0-9]+)\.env/\1/'
    return 0
  fi

  
  # Heuristic fallback via lspci name (engine only, no version)
  if [ -z "$OUT_ENGINE" ]; then
    local NAME_LINE=""
    if command -v lspci >/dev/null 2>&1; then
      # Prefer exported AMD_PCI_ADDR/PCI_ADDR if available; else pick first AMD VGA/Display
      local _pci="${AMD_PCI_ADDR:-${PCI_ADDR:-}}"
      if [ -n "$_pci" ]; then
        NAME_LINE="$(lspci -s "${_pci#0000:}" -nn 2>/dev/null || true)"
      else
        NAME_LINE="$(lspci -nn 2>/dev/null | grep -iE 'VGA.*AMD|Display.*AMD' | head -n1 || true)"
      fi
    fi
    # Normalize
    NAME_LINE="$(printf '%s' "$NAME_LINE" | tr '[:upper:]' '[:lower:]')"
    if printf '%s' "$NAME_LINE" | grep -qE '(navi|rdna|sienna|phoenix|rembrandt|vangogh|aero|merce|navi [0-9]+)'; then
      OUT_ENGINE="DCN"
      OUT_VERSION=""
      echo "Engine detect: heuristic => DCN (from lspci name: $NAME_LINE)" >> /userdata/system/logs/BUILD_15KHz_Batocera.log
    elif printf '%s' "$NAME_LINE" | grep -qE '(polaris|tonga|hawaii|bonaire|pitcairn|kabini|kaveri|carrizo|stoney|cape verde|curacao|oland|tahiti|verde|gfx7|gfx8)'; then
      OUT_ENGINE="DCE"
      OUT_VERSION=""
      echo "Engine detect: heuristic => DCE (from lspci name: $NAME_LINE)" >> /userdata/system/logs/BUILD_15KHz_Batocera.log
    fi
  fi
return 1
}


# Source the env file belonging to the selected connector and export key vars
use_connector_env() {
  local conn="$1" idx env
  idx="$(get_card_index_for_connector "$conn")" || return 1
  env="/tmp/crt-detect/card${idx}.env"
  [[ -r "$env" ]] || return 2
  # shellcheck disable=SC1090
  . "$env"
  export AMD_IS_APU DISPLAY_ENGINE DISPLAY_VERSION AMD_CARD_INDEX AMD_PCI_ADDR AMD_VENDOR AMD_DEVICE
  export APU_REASON
}

# Bind to the connector we’ll actually drive (CHOSEN/video_output).
# Try AMD card env first; if not AMD (Intel/NVIDIA), fall back to generic mode.
if use_connector_env "$video_output"; then
  # We’re on the AMD path and have loaded the per-card env.

  # Mirror to OUT_* for callers that expect them
  OUT_ENGINE="${OUT_ENGINE:-$DISPLAY_ENGINE}"
  OUT_VERSION="${OUT_VERSION:-$DISPLAY_VERSION}"

  # Fallback: if pre-scan/env didn’t set these, compute them now for the chosen AMD card
  if [ -z "${DISPLAY_ENGINE:-}" ]; then
    if command -v read_engine_anywhere >/dev/null 2>&1; then
      # Prefer the per-card detector (most accurate)
      read_engine_anywhere "${AMD_CARD_INDEX:-}"
      DISPLAY_ENGINE="${OUT_ENGINE:-${DISPLAY_ENGINE:-${PARSED_ENGINE:-unknown}}}"
      DISPLAY_VERSION="${OUT_VERSION:-${DISPLAY_VERSION:-${PARSED_VERSION:-}}}"
    else
      # Generic aggregate (last resort)
      {
        for f in /sys/kernel/debug/dri/*/amdgpu_dm_status /sys/kernel/debug/dri/*/amdgpu_pm_info; do
          [ -r "$f" ] && cat "$f"
        done
        dmesg
      } | parse_display_engine_from_text
      DISPLAY_ENGINE="${DISPLAY_ENGINE:-${PARSED_ENGINE:-unknown}}"
      DISPLAY_VERSION="${DISPLAY_VERSION:-${PARSED_VERSION:-}}"
    fi

    # Keep OUT_* in sync if we just populated them
    OUT_ENGINE="$DISPLAY_ENGINE"
    OUT_VERSION="$DISPLAY_VERSION"
  fi

	# Back-compat aliases: some older code still uses these names
	PCI_ADDR="${PCI_ADDR:-${AMD_PCI_ADDR:-}}"
	CARD_INDEX="${CARD_INDEX:-${AMD_CARD_INDEX:-}}"

else
  echo "WARN: Non-AMD GPU or no AMD env for '$video_output'; continuing in generic mode." >> "$LOG_FILE"

  # Neutral, safe defaults for non-AMD paths
  AMD_IS_APU=0
  DISPLAY_ENGINE="${DISPLAY_ENGINE:-GENERIC}"
  DISPLAY_VERSION="${DISPLAY_VERSION:-}"
  AMD_CARD_INDEX=""
  AMD_PCI_ADDR=""
  AMD_VENDOR=""
  AMD_DEVICE=""

  # Prevent 'OUT_*: unbound variable' downstream
  OUT_ENGINE="${OUT_ENGINE:-$DISPLAY_ENGINE}"
  OUT_VERSION="${OUT_VERSION:-$DISPLAY_VERSION}"
  PCI_ADDR="${PCI_ADDR:-}"
  CARD_INDEX="${CARD_INDEX:-}"
fi

# APU / not-APU banner (now that we know the correct card)
if [ "${AMD_IS_APU:-0}" -eq 1 ]; then
  box_hash
  # keep exact original wording for compatibility
  box_center "YOUR VIDEO CARD IS ${GREEN}AN AMD APU${NOCOLOR}"
  box_empty
  # added explanation (safe to change)
  box_center "APU = CPU with built-in Radeon graphics (integrated)."
  box_center "No separate graphics card is required."
  box_hash
  box_empty
else
  box_hash
  # keep exact original wording for compatibility
  box_center "YOUR VIDEO CARD IS NOT ${GREEN}AN AMD APU${NOCOLOR}"
  box_empty
  # added explanation (safe to change)
  box_center "This system is using a discrete GPU (a separate graphics card)."
  box_center "Desktop dGPU or mobile dGPU behaves the same for this script."
  box_hash
  box_empty
fi

center_plain_log "CRT bind: ${video_output} -> card${AMD_CARD_INDEX} (${AMD_PCI_ADDR}) | ${DISPLAY_ENGINE}${DISPLAY_VERSION:+ ${DISPLAY_VERSION}} | AMD_IS_APU=${AMD_IS_APU}"

# Log which kernel driver is bound (amdgpu vs radeon), useful when engine=NONE
if [ -n "${AMD_CARD_INDEX:-}" ] && [ -e "/sys/class/drm/card${AMD_CARD_INDEX}/device/driver" ]; then
  _drv="$(basename "$(readlink -f "/sys/class/drm/card${AMD_CARD_INDEX}/device/driver")")"
  echo "Kernel driver for card${AMD_CARD_INDEX}: ${_drv}" >> /userdata/system/logs/BUILD_15KHz_Batocera.log
fi


box_hash
box_center "Display Engine: ${GREEN}${DISPLAY_ENGINE:-NONE}${NOCOLOR}${DISPLAY_VERSION:+ v${DISPLAY_VERSION}}"
box_hash
echo "Display engine summary: ${DISPLAY_ENGINE:-NONE} ${DISPLAY_VERSION}" >> /userdata/system/logs/BUILD_15KHz_Batocera.log

# -------------------- Sea Islands (GCN 2.x — DCE 8.x) guardrail --------------------
# Applies to: Bonaire, Hawaii, Kaveri, Kabini, Mullins (GCN 2.x / DCE 8.x)
# Wiki: Interlace unsupported on amdgpu — use radeon.
# https://github.com/ZFEbHVUE/Batocera-CRT-Script/wik

# Sea Islands guardrail gate (hardened to only run when an AMD card is actually bound)
if declare -F is_sea_islands_chip >/dev/null 2>&1 \
   && declare -F get_bound_driver   >/dev/null 2>&1 \
   && declare -F offer_switch_to_radeon >/dev/null 2>&1 \
   && [ -n "${AMD_CARD_INDEX:-}" ]; then
  if is_sea_islands_chip; then
    _drv="$(get_bound_driver)"
    echo "Sea Islands detection: driver=${_drv}, engine=${DISPLAY_ENGINE:-NONE}, apu=${AMD_IS_APU}" >> /userdata/system/logs/BUILD_15KHz_Batocera.log
    if [ "$_drv" = "amdgpu" ]; then
      offer_switch_to_radeon
    else
      echo "Sea Islands under radeon: OK for interlace." >> /userdata/system/logs/BUILD_15KHz_Batocera.log
    fi
  fi
else
  echo "Sea Islands check skipped (helper functions missing or no AMD card bound)" >> /userdata/system/logs/BUILD_15KHz_Batocera.log
fi


is_sea_islands_chip() {
  # Prefer CHIP_* family if exposed earlier (e.g., parsed from list_detection_amd_apu.txt)
  # Fallback: lspci product string probe
  local hint="${CHIP_FAMILY:-}"
  if [ -z "$hint" ]; then
    local l=""
    if command -v lspci >/dev/null 2>&1; then
      l="$(lspci -s "${AMD_PCI_ADDR#0000:}" -nn 2>/dev/null | tr '[:upper:]' '[:lower:]')"
    fi
    hint="$l"
  fi
  printf '%s' "$hint" | grep -qiE '(chip_)?(bonaire|hawaii|kaveri|kabini|mullins)' && return 0
  # Some kernel trees use older internal codenames
  printf '%s' "$hint" | grep -qiE '(kalindi|spectre|spooky)' && return 0
  return 1
}

get_bound_driver() {
  local dev="/sys/class/drm/card${AMD_CARD_INDEX}/device"
  local drv=""; drv="$(basename "$(readlink -f "$dev/driver" 2>/dev/null)" 2>/dev/null || true)"
  printf '%s' "$drv"
}

offer_switch_to_radeon() {
  local conf="/boot/batocera-boot.conf"
  local bak="/boot/batocera-boot.conf.bak_sea_islands"
  echo "Sea Islands: offering driver switch; editing $conf with backup $bak" >> /userdata/system/logs/BUILD_15KHz_Batocera.log

  box_hash
  box_center "Sea Islands (GCN 2.x / DCE 8.x) detected under ${GREEN}amdgpu${NOCOLOR}."
  box_center "Interlace is ${RED}unsupported${NOCOLOR} on amdgpu for this family."
  box_empty
  box_center "Recommended: switch to ${GREEN}radeon${NOCOLOR} driver in /boot/batocera-boot.conf"
  box_center "(this sets: amdgpu=false)"
  box_hash
  prompt_centered_tty "PRESS ${BLUE}ENTER${NOCOLOR} TO APPLY (or Ctrl+C to keep amdgpu)"

  mount -o remount,rw /boot 2>/dev/null || true
  cp -f "$conf" "$bak" 2>/dev/null || true

  if grep -q '^ *amdgpu=' "$conf" 2>/dev/null; then
    sed -i 's/^ *amdgpu=.*/amdgpu=false/' "$conf"
  else
    printf '\n# Force radeon for Sea Islands (GCN 2.x)\namdgpu=false\n' >> "$conf"
  fi

  sync
  box_hash
  box_center "batocera-boot.conf updated (${GREEN}amdgpu=false${NOCOLOR})."
  box_center "Reboot to load the radeon driver and enable interlace."
  box_hash
  echo "Sea Islands: wrote amdgpu=false to $conf (backup at $bak)" >> /userdata/system/logs/BUILD_15KHz_Batocera.log

  # --- Safe immediate reboot (with cancel window) ---
  box_empty
  box_center "Reboot required to load ${GREEN}radeon${NOCOLOR}."
  box_center "System will reboot in 15 seconds…  (press Ctrl+C to cancel)"
  box_hash

  sync
  mount -o remount,ro /boot 2>/dev/null || true

  for s in $(seq 15 -1 1); do
    printf "\rRebooting in %2d s…  " "$s"
    sleep 1
  done
  echo
  echo "Sea Islands: initiating reboot now." >> /userdata/system/logs/BUILD_15KHz_Batocera.log
  reboot
}
# -------------------------------------------------------------------------------


########################################################################################
# --- Bind selected connector to owning AMD card — load env + banner END ---       #####
########################################################################################

echo "#######################################################################"
echo "##                         CRT Output Selected                       ##"
echo "#######################################################################"
echo
echo -e "   You have chosen output name:  ${GREEN}${video_output}${NOCOLOR}"
echo "  -> Owner: card${AMD_CARD_INDEX} (${AMD_PCI_ADDR}) | ${DISPLAY_ENGINE}${DISPLAY_VERSION:+ ${DISPLAY_VERSION}} | AMD_IS_APU=${AMD_IS_APU}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
echo "   This connector will remain enabled; all others will be ignored via Xorg."
echo
echo "#######################################################################"
echo
echo -n -e "   PRESS ${BLUE}ENTER${NOCOLOR} TO CONTINUE "
read -r

# Log to the build log (like the old code did)
echo "CRT output selected: ${video_output}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log


########################################################################################
#####################              15KHz/25KHz/31KHz                  ##################
########################################################################################
CRT_Freq="15KHz"





########################################################################################
#####################               GENERAL  MONITOR                  ##################
########################################################################################



if [ ! -f "/etc/switchres.ini.bak" ];then
	cp /etc/switchres.ini /etc/switchres.ini.bak
fi

echo
#########################################################################################
declare -a type_of_monitor=( 	"generic_15" "ntsc" "pal" "arcade_15" "arcade_15ex" "arcade_25" "arcade_31" \
				"arcade_15_25" "arcade_15_31" "arcade_15_25_31" "vesa_480" "vesa_600" "vesa_768" "vesa_1024" \
				"pc_31_120" "pc_70_120" "h9110" "polo" "pstar" "k7000" "k7131" "d9200" "d9400" "d9800" \
				"m2929" "m3129" "ms2930" "ms929" "r666b"  )  

categories=(			"Generic CRT standards 15 KHz" "Arcade fixed frequency 15 KHz" "Arcade fixed frequency 25/31KHz" \
	    			"Arcade multisync 15/25/31 KHz" "VESA GTF" "PC monitor 120 Hz" "Hantarex" "Wells Gardner" "Makvision" \
	    			"Wei-Ya" "Nanao" "Rodotron")
#########################################################################################
declare -A monitor_categories
monitor_categories["Generic CRT standards 15 KHz"]="generic_15 ntsc pal"
monitor_categories["Arcade fixed frequency 15 KHz"]="arcade_15 arcade_15ex"
monitor_categories["Arcade fixed frequency 25/31KHz"]="arcade_25 arcade_31"
monitor_categories["Arcade multisync 15/25/31 KHz"]="arcade_15_25 arcade_15_31 arcade_15_25_31"
monitor_categories["VESA GTF"]="vesa_480 vesa_600 vesa_768 vesa_1024"
monitor_categories["PC monitor 120 Hz"]="pc_31_120 pc_70_120"
monitor_categories["Hantarex"]="h9110 polo pstar"
monitor_categories["Wells Gardner"]="k7000 k7131 d9200 d9400 d9800"
monitor_categories["Makvision"]="m2929"
monitor_categories["Wei-Ya"]="m3129"
monitor_categories["Nanao"]="ms2930 ms929"
monitor_categories["Rodotron"]="r666b" 
#########################################################################################
counter=0
echo "#######################################################################"
echo "##                     your type of monitor                          ##"
echo "#######################################################################"

for category in "${categories[@]}"; do
  echo ""	
  echo "	$category :"
  monitors="${monitor_categories[$category]}"
  IFS=" " read -ra monitor_array <<< "$monitors"
  for i in "${!monitor_array[@]}"; do
    echo "						$((counter + i + 1)) : ${monitor_array[i]}"
  done
  counter=$((counter + ${#monitor_array[@]}))
done

# Define the log file path
log_file="/userdata/system/logs/BootRes.log"
echo ""
echo "#######################################################################"
echo "##                 Make your choice for monitor type                 ##"
echo "#######################################################################"
echo -n "                                  "
while true; do
  read -r monitor_choice
  if [[ "$monitor_choice" =~ ^[0-9]+$ ]] && (( monitor_choice >= 1 && monitor_choice <= ${#type_of_monitor[@]} )); then
    break
  fi
  echo -n "Invalid choice. Please enter a number between 1 and ${#type_of_monitor[@]}: "
done

monitor_firmware=${type_of_monitor[monitor_choice-1]}

IFE=0
Amd_NvidiaND_IntelDP=0
Intel_Nvidia_NOUV=0

if ([ "$TYPE_OF_CARD" == "NVIDIA" ] && [ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]) || ([ "$TYPE_OF_CARD" == "AMD/ATI" ]) || ([ "$TYPE_OF_CARD" == "INTEL" ] && [[ $video_output == *"DP"* ]]); then
  
   # Original matrix strings
    	matrix=("arcade_15 320x240@60 640x480@30 768x576@25" "arcade_15_25 320x240@60 640x480@30 768x576@25 1024x576@25 1024x768@30" "arcade_15_31 320x240@60 640x480@30 768x576@25 1024x576@25 1024x768@30"
            	"arcade_15_25_31 320x240@60 640x480@30 768x576@25 1024x576@25 1024x768@25" "arcade_15ex 320x240@60 640x480@25 768 x576@25"
            	"arcade_25 498x384@60 512x384@60 1024x768@30 1072x800@25" "arcade_31 640x480@60" "d9200 320x240@60 640x480@60 768x576@50 800x600@60 1028x576@50"
            	"d9400 320x240@60 640x480@60 768x576@50 800x600@60 1028x576@50" "d9800 320x240@60 640x480@60 768x576@50 800x600@60 1028x576@50"
            	"generic_15 320x240@60 640x480@30 768x576@25" "h9110 320x240@60 640x480@30 768x576@25 1028x576@25" "k7000 320x240@60 640x480@30 768x576@25 1028x576@25"
            	"k7131 320x240@60 640x480@30 768x576@25 1028x576@25" "m2929 640x480@60 768x576@50 800x600@60 1028x576@50" "m3129 320x240@60 640x480@60 768x576@25 1028x576@25"
            	"ms2930 320x240@60 640x480@60 768x576@25 1028x576@25" "ms929 320x240@60 640x480@60 768x576@25 1028x576@25" "ntsc 320x240@60 640x480@30"
            	"pal 320x240@60 640x480@60 768x576@25 1028x576@25" "pc_31_120 320x240@60 640x480@60" "pc_70_120 320x240@60 640x480@60 768x576@50 800x600@60 1024x576@25 1024x768@50"
            	"polo 320x240@60 640x480@60 768x576@25 1024x576@25" "pstar 320x240@60 640x480@60 1024x768@25" "r666b 320x240@60 640x480@60 768x576@25 1024x576@25"
            	"vesa_480 640x480@60 768x576@50" "vesa_600 640x480@60 768x576@50 800x600@60 1024x576@50" "vesa_768 640x480@60 768x576@50 800x600@60 1024x576@50"
            	"vesa_1024 640x480@60 768x576@50 800x600@60 1024x576@50 1024x768@50")
 
 
    # Parity must follow the display engine (Calamity): DCN => even, DCE/unknown => off
    if [ "$TYPE_OF_CARD" = "AMD/ATI" ] && [ "${DISPLAY_ENGINE:-NONE}" = "DCN" ]; then
       IFE=1
    else
       IFE=0
    fi
# Log the decision for clarity
echo "Parity decision: interlace_force_even=${IFE} (engine=${DISPLAY_ENGINE}${DISPLAY_VERSION:+ ${DISPLAY_VERSION}})" \
  | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log >/dev/null

# If we couldn't read DCN/DCE (e.g., debugfs not mounted or radeon driver), note why IFE stayed 0
if [ "${DISPLAY_ENGINE:-NONE}" = "NONE" ]; then
  echo "Note: DISPLAY_ENGINE is NONE (no amdgpu_ip_info). interlace_force_even set to ${IFE}." \
    >> /userdata/system/logs/BUILD_15KHz_Batocera.log
fi

    Amd_NvidiaND_IntelDP=1
else
    # Original matrix strings
     	matrix=("arcade_15 1280x240@60 1280x480@30 1280x576@25" "arcade_15_25 1280x240@60 1280x480@30" "arcade_15_31 1280x240@60 1280x480@30" "arcade_15_25_31 1280x240@60 1280x480@30"
            	"arcade_15ex 1280x240@60 1280x480@30 1280x576@25" "arcade_25 1280x768@30 1280x800@25" "arcade_31 1280x480@60" "d9200 1280x240@60 1280x480@60" "d9400 1280x240@60 1280x480@60"
            	"d9800 1280x240@60 1280x480@60" "generic_15 1280x240@60 1280x480@30 1280x576@25" "h9110 1280x240@60 1280x480@30" "k7000 1280x240@60 1280x480@30" "k7131 1280x240@60 1280x480@30"
            	"m2929 1280x480@60" "m3129 1280x240@60 1280x480@60" "ms2930 1280x240@60 1280x480@60" "ms929 1280x240@60 1280x480@60" "ntsc 1280x240@60 1280x480@60" "pal 1280x240@60 1280x480@60"
            	"pc_31_120 1280x240@60 1280x480@60" "pc_70_120 1280x240@60 1280x480@60"  "polo 1280x240@60 1280x480@60" "pstar 1280x240@60 1280x480@60" "r666b 1280x240@60 1280x480@60"
            	"vesa_480 1280x480@60" "vesa_600 1280x480@60" "vesa_768 1280x480@60" "vesa_1024 1280x480@60")

    Intel_Nvidia_NOUV=1
fi

# Find the line in the matrix that corresponds to the selected monitor firmware
monitor_firmware_info=""
for line in "${matrix[@]}"; do

  if [[ "$line" == "$monitor_firmware"* ]]; then

   monitor_firmware_info="$line"
    break
  fi
done

# If the selected monitor firmware is not found, display an error message
if [ -z "$monitor_firmware_info" ]; then
  echo "monitor_firmware_info=Monitor firmware not found in the matrix."
  exit 1
fi

# Split the line into an array using space as the delimiter
IFS=' ' read -ra monitor_info <<< "$monitor_firmware_info"

# Display monitor information
echo "	Information for monitor ${monitor_info[0]}:"

# Display resolution options with centered alignment
for ((i = 1; i < ${#monitor_info[@]}; i++)); do
  printf "						%s\n" "$(printf "%2d : %s" $i "${monitor_info[i]}")"
done

echo ""
echo "#######################################################################"
echo "##       Make your choice for the EDID Resolution                    ##"
echo "#######################################################################"
echo -n "                                  "

# monitor_info[0] is the firmware name; valid choices start at 1
max_choice=$(( ${#monitor_info[@]} - 1 ))

# Re-prompt until the user provides a valid number
while true; do
  read -r EDID_resolution_choice
  if [[ "$EDID_resolution_choice" =~ ^[0-9]+$ ]] && (( EDID_resolution_choice >= 1 && EDID_resolution_choice <= max_choice )); then
    break
  fi
  echo -n "Invalid choice. Please enter a number between 1 and ${max_choice}: "
done

EDID_resolution=${monitor_info[EDID_resolution_choice]}
echo -e "				Your choice is :  ${GREEN}$EDID_resolution${NOCOLOR}"

# Log the resolution choice
{
    echo "Monitor Type: $monitor_firmware"
    echo "Boot Resolution: $EDID_resolution"
} > "$log_file"

IFS="x@ " read -r H_RES_EDID V_RES_EDID FREQ_EDID <<< "$EDID_resolution"


################################################################################################################################
##  HERE FOR NVIDIA-DRIVERS (BEFORE THE EDID IN 99-NVIDIA.CONF) : ADD 1 ON H RESOLUTION (EmulationStation) 
##  TO AVOID THE CONFLICT WITH GEOMETRY TOOLS FOR SAME RESOLTION OF ES
################################################################################################################################
if ([ "$TYPE_OF_CARD" == "NVIDIA" ] && [ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]); then
	H_RES_EDID=$((H_RES_EDID+1))
fi
################################################################################################################################

RES_EDID="${H_RES_EDID}x${V_RES_EDID}"
if [ "$FREQ_EDID" == "50" ] || [ "$FREQ_EDID" == "60" ]; then 
	RES_EDID_SCANNING="${H_RES_EDID}x${V_RES_EDID}p"
elif [ "$FREQ_EDID" == "25" ] || [ "$FREQ_EDID" == "30" ]; then
	RES_EDID_SCANNING="${H_RES_EDID}x${V_RES_EDID}i"
else
	echo "problems of frame rate to determine progressif or interlace"
fi

# --- Decide whether the EDID itself should be generated with +1 horizontal ---
# Default: no pre-bump (nounset-safe)
_EDID_PRE_BUMP=1

# Normalize casing once
_TC_NORM="${TYPE_OF_CARD^^}"
_DRV_NORM="${Drivers_Nvidia_CHOICE^^}"

# Apply pre-bump for vendors where we want the EDID itself to carry +1 width
# (NVIDIA proprietary + nouveau, AMD/APU, Intel)
if [[ ( "$_TC_NORM" == "NVIDIA" && ( "$_DRV_NORM" == "NVIDIA_DRIVERS" || "$_DRV_NORM" == "NOUVEAU" ) ) \
   || "$_TC_NORM" == "AMD" || "$_TC_NORM" == "AMD/ATI" \
   || "$_TC_NORM" == "INTEL" ]]; then
  H_RES_EDID=$(( H_RES_EDID + 1 ))
  _EDID_PRE_BUMP=1
  echo "DEBUG: EDID PRE-bump applied; EDID will be generated at ${H_RES_EDID}x${V_RES_EDID}" \
    | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log >/dev/null
fi

FORCED_EDID="${H_RES_EDID}x${V_RES_EDID}@${FREQ_EDID}"
Name_monitor_EDID=$monitor_firmware
sed -i "s/.*monitor         .*/        monitor                   $Name_monitor_EDID/" /etc/switchres.ini
DOTCLOCK_MIN_SWITCHRES=0
sed -i "s/.*dotclock_min        .*/    dotclock_min              $DOTCLOCK_MIN_SWITCHRES/" /etc/switchres.ini
sed -i "s/.*interlace_force_even   .*/        interlace_force_even      $IFE/" /etc/switchres.ini

#switchres $H_RES_EDID $V_RES_EDID $FREQ_EDID -f $FORCED_EDID -m $Name_monitor_EDID  -e  #> /dev/null 2>/dev/null
#
switchres $H_RES_EDID $V_RES_EDID $FREQ_EDID -f $FORCED_EDID -i switchres.ini -e  > /dev/null 2>/dev/null
echo "EDID build: switchres $H_RES_EDID $V_RES_EDID $FREQ_EDID -f $FORCED_EDID -i switchres.ini -e  (IFE=$IFE, engine=${DISPLAY_ENGINE}${DISPLAY_VERSION:+ ${DISPLAY_VERSION}})" \
  | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log >/dev/null

Name_monitor_EDID+=".bin"

if [ ! -d /lib/firmware/edid ]; then
	mkdir /lib/firmware/edid
fi

patch_edid=$(pwd)
cp $patch_edid/$Name_monitor_EDID  /lib/firmware/edid/
chmod 644  /lib/firmware/edid/$Name_monitor_EDID 
rm $patch_edid/$Name_monitor_EDID   

################################################################################################################################
##  HERE FOR OTHER CARDS (AFTER CREATION OF EDID) : ADD 1 ON H RESOLUTION (EmulationStation)
##  TO AVOID THE CONFLICT WITH GEOMETRY TOOLS FOR SAME RESOLUTION OF ES
################################################################################################################################
# Normalize for case/wording differences across the script (AMD vs AMD/ATI casing, nouveau casing, etc.)
_TC_NORM="${TYPE_OF_CARD^^}"
_DRV_NORM="${Drivers_Nvidia_CHOICE^^}"

echo "DEBUG: EDID post-adjust check -> TYPE_OF_CARD='${TYPE_OF_CARD}' (norm='${_TC_NORM}'), Drivers_Nvidia_CHOICE='${Drivers_Nvidia_CHOICE}' (norm='${_DRV_NORM}'), H_RES_EDID(before)=${H_RES_EDID}" \
  | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log >/dev/null

# If we already pre-bumped for the EDID file, skip the post-bump (prevents double +1)
if (( _EDID_PRE_BUMP )); then
  echo "DEBUG: Skipping post-EDID bump because pre-bump was applied; H_RES_EDID=${H_RES_EDID}" \
    | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log >/dev/null
else
  # Apply +1 for: NVIDIA (NOUVEAU only), AMD (any spelling), and INTEL
  # Proprietary NVIDIA is handled earlier (pre-EDID block), so we exclude it here.
  if [[ ( "${_TC_NORM}" == "NVIDIA" && "${_DRV_NORM}" == "NOUVEAU" ) \
     || "${_TC_NORM}" == "AMD" || "${_TC_NORM}" == "AMD/ATI" \
     || "${_TC_NORM}" == "INTEL" ]]; then
    H_RES_EDID=$(( H_RES_EDID + 1 ))
    echo "DEBUG: Post-EDID bump applied; H_RES_EDID(after)=${H_RES_EDID}" \
      | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log >/dev/null
  else
    echo "DEBUG: No post-EDID bump for (${_TC_NORM}/${_DRV_NORM}); H_RES_EDID remains ${H_RES_EDID}" \
      | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log >/dev/null
  fi
fi

################################################################################################################################

#if [ "$TYPE_OF_CARD" == "NVIDIA" ]&&[ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]; then 
MODE=$(switchres $H_RES_EDID $V_RES_EDID $FREQ_EDID -f $FORCED_EDID -i switchres.ini -c ) > /dev/null 2>/dev/null
################################################################################################################################
################################################################################################################################
MODELINE_PARAMETERS=$(echo "$MODE" | sed -n 's/.*Modeline "[^"]*" \([0-9.]\+\) \([0-9 ]\+\) \(.*\)/\1 \2 \3/p')
read -r Pixel_Clock H_res HF_Porch H_Sync HB_Porch V_res VF_Porch V_Sync VB_Porch Inter HSync VSync <<< "$MODELINE_PARAMETERS"
if [[ "$MODELINE_PARAMETERS" == *"interlace"* ]]; then
    Interlace=2
else
    Interlace=1
fi
Frame_Rate=$(echo "$(echo "$(echo "$Pixel_Clock*1000000" | bc -l)/$(($((H_res+$((HB_Porch-H_res))))*$((V_res+$((VB_Porch-V_res))))))" | bc -l)*$Interlace" | bc -l)
Frame_Rate=$(printf "%.2f" $Frame_Rate)
Resolution_es=""es.resolution=""${H_RES_EDID}"x"${V_RES_EDID}"."${Frame_Rate}"000"
################################################################################################################################
###############################################################################################################################
MODELINE_CUSTOM="\"${RES_EDID}\" $(echo "$MODE" | sed -n 's/.*Modeline "[^"]*" \([0-9.]\+\) \([0-9 ]\+\) \(.*\)/\1 \2 \3/p')"
monitor_name_MAME=$monitor_firmware
echo "monitor mame = $monitor_name_MAME"  >> /userdata/system/logs/BUILD_15KHz_Batocera.log
Name_VideoModes="videomodes.conf_"$monitor_firmware
if [ "$Amd_NvidiaND_IntelDP" == "1" ]; then
	cp /userdata/system/Batocera-CRT-Script/System_configs/VideoModes/Amd_NvidiaND_IntelDP/$Name_VideoModes /userdata/system/videomodes.conf
elif [ "$Intel_Nvidia_NOUV" == "1" ]; then
	cp /userdata/system/Batocera-CRT-Script/System_configs/VideoModes/Intel_NvidiaNOUV/$Name_VideoModes /userdata/system/videomodes.conf
else
	echo "Problems"
fi
chmod 644 /userdata/system/videomodes.conf
chmod 644 /userdata/system/videomodes.conf
cp /userdata/system/videomodes.conf /userdata/system/videomodes.conf.bak 
########################################################################################
#####################              BOOT RESOLUTION        ##############################
########################################################################################
boot_resolution="e"
#echo "Boot resolution = $boot_resolution" >> /userdata/system/logs/BUILD_15KHz_Batocera.log
################################################################################################################################
#####################              ES RESOLUTION          ######################################################################

################################################################################################################################
#echo "ES_resolution = $ES_resolution" >> /userdata/system/logs/BUILD_15KHz_Batocera.log

################################################################################################################################
#######################################                  ROTATION                   ############################################
################################################################################################################################
echo -n -e "                       PRESS ${BLUE}ENTER${NOCOLOR} TO CONTINUE "
read
echo
echo ""
echo "#######################################################################"
echo "##                          ROTATING SCREEN                          ##"
echo "##                                                                   ##"
echo "##       SET THE ACTUAL PHYSICAL ORIENTATION OF YOUR MONITOR         ##"
echo "##         AND THE DIRECTION OF ROTATION (HORIZONTAL ↔ VERTICAL)     ##"
echo "##                                                                   ##"
echo "##   If you use your monitor normally (no physical rotation),        ##"
echo "##   select: NONE                                                    ##"
echo "##                                                                   ##"
echo "##                           IMPORTANT                               ##"
echo "##                                                                   ##"
echo "##   ┌──────────────────────────────┐                                 ##"
echo "##   │        EMULATOR NOTES        │                                 ##"
echo "##   └──────────────────────────────┘                                 ##"
echo "##                                                                   ##"
echo "##   ● MAME (GroovyMAME): Works for all horizontal and vertical       ##"
echo "##     games automatically on any screen orientation.                ##"
echo "##                                                                   ##"
echo "##   ● FBNeo:                                                        ##"
echo "##       - Horizontal screen → Horizontal games (no rotation)        ##"
echo "##                              Vertical games (rotated)             ##"
echo "##       - Vertical screen   → Horizontal games (rotated)            ##"
echo "##                              Vertical games (no rotation)         ##"
echo "##                                                                   ##"
echo "##   ● Libretro cores: Works for all horizontal games.               ##"
echo "##     Some TATE (vertical) modes may have rotation issues.          ##"
echo "##                                                                   ##"
echo "##   ● Standalone emulators: Works for horizontal games on           ##"
echo "##     rotated screens. Some vertical modes may show bugs.           ##"
echo "##                                                                   ##"
echo "##   ● Future Pinball: Works correctly in both horizontal and         ##"
echo "##     vertical (portrait) display modes.                            ##"
echo "##                                                                   ##"
echo "##   These options allow you to play classic horizontal games on     ##"
echo "##   vertical monitors — with or without rotation — across           ##"
echo "##   various emulators. Remember: by default, emulators run          ##"
echo "##   in horizontal mode (no rotation).                               ##"
echo "##                                                                   ##"
echo "##   Only GroovyMAME automatically detects whether a game is         ##"
echo "##   horizontal or vertical and adjusts rotation accordingly.        ##"
echo "##                                                                   ##"
echo "#######################################################################"
echo ""
declare -a Screen_rotating=( "None" "Clockwise" "Counter-Clockwise" )
for var in "${!Screen_rotating[@]}" ; do echo "			$((var+1)) : ${Screen_rotating[$var]}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log; done
echo ""
echo "#######################################################################"
echo "##       Make your choice for the sens of your rotation screen       ##"  | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
echo "#######################################################################"
echo -n "                                  "
read Screen_rotating_choice
	while [[ ! ${Screen_rotating_choice} =~ ^[1-$((var+1))]$ ]] ; do
		echo -n "Select option 1 to $((var+1)):"
		read Screen_rotating_choice
	done
Rotating_screen=${Screen_rotating[$Screen_rotating_choice-1]}

echo -e "                    Your choice is : ${GREEN} $Rotating_screen${NOCOLOR}"  | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
echo ""
echo "#######################################################################"
echo "##                     EMULATIONSTATION ORIENTATION                  ##"
echo "##                  MONITOR SETUP (FROM HORIZONTAL)                  ##"
echo "##                                                                   ##"
echo "##  HORIZONTAL (Default)             →  NORMAL     (0°)              ##"
echo "##  VERTICAL (Counter-Clockwise)     →  TATE90     (90°)             ##"
echo "##  HORIZONTAL (Upside Down)         →  INVERTED   (180°)            ##"
echo "##  VERTICAL (Clockwise)             →  TATE270    (270° or -90°)    ##"
echo "##                                                                   ##"
echo "#######################################################################"
echo ""
declare -a ES_orientation=( "NORMAL" "TATE90" "INVERTED" "TATE270" )
if ([ "$TYPE_OF_CARD" == "NVIDIA" ]&&[ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]); then
	declare -a display_rotation=( "normal" "normal" "normal" "normal" )
	declare -a display_mame_rotation=( "normal" "left" "normal" "right" )
	case $Rotating_screen in
		None)
			declare -a display_libretro_rotation=( "normal" "right" "normal" "right" )
			declare -a display_standalone_rotation=( "normal" "normal" "normal" "normal" )
			declare -a display_fbneo_rotation=( "normal" "right" "normal" "right" )
		;;
		Clockwise)
			declare -a display_libretro_rotation=( "normal" "left" "normal" "right")
			declare -a display_standalone_rotation=( "normal" "left" "normal" "left" )
			declare -a display_fbneo_rotation=( "normal" "right" "normal" "right" )

		;;
		Counter-Clockwise)
			declare -a display_libretro_rotation=( "normal" "right" "normal"  "right" )
			declare -a display_standalone_rotation=( "normal" "right" "normal" "right" )
			declare -a display_fbneo_rotation=( "normal" "right" "normal" "right" )
		;;
		*)
			echo "problems of choice of rotation"
		;;
	esac
else
	declare -a display_rotation=( "normal" "right" "inverted" "left" )
	declare -a display_mame_rotation=( "normal" "normal" "inverted" "normal" )
	case $Rotating_screen in
		None)
			declare -a display_libretro_rotation=( "normal" "right" "inverted" "left" )
			declare -a display_standalone_rotation=( "normal" "right" "inverted" "left" )
			declare -a display_fbneo_rotation=( "normal" "inverted" "inverted" "normal" )
		;;
		Clockwise)
			declare -a display_libretro_rotation=( "normal" "normal" "inverted" "inverted" )
			declare -a display_standalone_rotation=( "normal" "normal" "inverted" "inverted" )
			declare -a display_fbneo_rotation=( "normal" "inverted" "inverted" "normal" )
		;;
		Counter-Clockwise)
			declare -a display_libretro_rotation=( "normal" "inverted" "inverted" "normal" )
			declare -a display_standalone_rotation=( "normal" "inverted" "inverted" "normal" )
			declare -a display_fbneo_rotation=( "normal" "inverted" "inverted" "normal" )
		;;
		*)
			echo "problems of choice of rotation"
		;;
	esac
fi
for var in "${!ES_orientation[@]}" ; do echo "			$((var+1)) : ${ES_orientation[$var]}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log; done
echo ""
echo "#######################################################################"
echo "##              Select your EmulationStation orientation             ##"
echo "##        (Choose the position that matches your monitor setup)      ##"
echo "#######################################################################"
echo -n "                                  "
read es_rotation_choice
while [[ ! ${es_rotation_choice} =~ ^[1-$((var+1))]$ ]] ; do
	echo -n "Select option 1 to $((var+1)):"
	read es_rotation_choice
done
ES_rotation=${ES_orientation[$es_rotation_choice-1]}
display_rotate=${display_rotation[$es_rotation_choice-1]}
display_mame_rotate=${display_mame_rotation[$es_rotation_choice-1]}
display_libretro_rotate=${display_libretro_rotation[$es_rotation_choice-1]}
display_standalone_rotate=${display_standalone_rotation[$es_rotation_choice-1]}
display_fbneo_rotate=${display_fbneo_rotation[$es_rotation_choice-1]}

echo -e "                    Your choice is :  ${GREEN}$ES_rotation${NOCOLOR}"  | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log

################################################################################################################################
##########################################      Super-resolutions       ########################################################
################################################################################################################################

super_width_vertical=1920
interlace_vertical=0
dotclock_min_vertical=25

super_width_horizont=1920
interlace_horizont=0
dotclock_min_horizont=25

if [ "$TYPE_OF_CARD" == "AMD/ATI" ]; then
	
	dotclock_min=0	
	dotclock_min_mame=$dotclock_min
	super_width=2560
	super_width_mame=2560 
	drivers_type=AMDGPU
	
	if [ "$R9_380" == "YES" ]; then
		drivers_amd="amdgpu.dc=0"
	else
		drivers_amd=""
	fi
	echo "AMDGPU" >> 	/userdata/system/logs/TYPE_OF_CARD_DRIVERS.info
	
	if [[ "$video_output" == *"DP"* ]]; then
		term_dp="DP"
		term_displayport="DisplayPort"
		video_display=$video_output
		nbr=$(sed 's/[^[:digit:]]//g' <<< "${video_output}")
		video_modeline=$video_output_xrandr
	elif [[ $video_output == *"DVI"* ]]; then
		nbr=$(sed 's/[^[:digit:]]//g' <<< "${video_output}")
		video_display=$video_output
	
  		term_DVI=DVI-I
		if [ "$R9_380" == "YES" ]; then
			video_modeline=$video_output_xrandr
		else
			video_modeline=$video_output_xrandr
		fi	
  
	elif [[ "$video_output" == *"VGA"* ]]; then
		term_VGA=VGA
		nbr=$(sed 's/[^[:digit:]]//g' <<< "${video_output}")
		video_display=$video_output
		video_modeline=$video_output_xrandr
	elif [[ "$video_output" == *"HDMI"* ]] ; then
		term_HDMI=HDMI-A
		nbr=$(sed 's/[^[:digit:]]//g' <<< "${video_output}")
		video_display=$video_output
 		video_modeline=$video_output_xrandr
		dotclock_min=25.0
		dotclock_min_mame=$dotclock_min
		super_width=3840
		super_width_mame=$super_width
	fi 
 elif [ "$TYPE_OF_CARD" == "INTEL" ]; then
	drivers_amd=""
	if [[ "$video_output" == *"DP"* ]]; then
		term_dp="DP"
		term_displayport="DisplayPort"
		video_display=$video_output 
		nbr=$(sed 's/[^[:digit:]]//g' <<< "${video_output}")
		video_modeline=$video_output_xrandr   
		dotclock_min=0
		dotclock_min_mame=$dotclock_min
		super_width=1920
		super_width_mame=$super_width
	elif [[ "$video_output" == *"VGA"* ]]; then
		term_VGA="VGA"
		nbr=$(sed 's/[^[:digit:]]//g' <<< "${video_output}")
		video_display=$video_output
		video_modeline=$video_output_xrandr
		dotclock_min=25.0
		dotclock_min_mame=$dotclock_min
		super_width=1920
		super_width_mame=$super_width
	fi
elif [ "$TYPE_OF_CARD" == "NVIDIA" ]; then
	drivers_amd=""
	if [[ "$video_output" == *"DP"* ]]; then
		term_dp="DP"
		term_displayport="DisplayPort"
		video_display=$video_output 
		nbr=$(sed 's/[^[:digit:]]//g' <<< "${video_output}")
		if [ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]; then
			if [ "$Drivers_Name_Nvidia_CHOICE" == "legacy470" ]||[ "$Drivers_Name_Nvidia_CHOICE" == "legacy390" ]||[ "$Drivers_Name_Nvidia_CHOICE" == "legacy340" ]; then
				video_modeline=$video_output_xrandr
				dotclock_min=0
				dotclock_min_mame=$dotclock_min
				super_width=3840
				super_width_mame=$super_width
			else
				video_modeline=$video_output_xrandr 
				dotclock_min=0
				dotclock_min_mame=$dotclock_min
				super_width=3840
				super_width_mame=$super_width
			fi
		else	
			video_modeline=$video_output_xrandr 
			dotclock_min=0
			super_width=3840
			super_width_mame=$super_width
		fi
	elif [[ "$video_output" == *"DVI"* ]]; then
		term_DVI=DVI-I
		nbr=$(sed 's/[^[:digit:]]//g' <<< "${video_output}")
		video_display=$video_output
		if [ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]; then
			if [ "$Drivers_Name_Nvidia_CHOICE" == "legacy470" ]||[ "$Drivers_Name_Nvidia_CHOICE" == "legacy390" ]||[ "$Drivers_Name_Nvidia_CHOICE" == "legacy340" ]; then
				video_modeline=$video_output_xrandr
				dotclock_min=25
				dotclock_min_mame=$dotclock_min
				super_width=3840
				super_width_mame=$super_width
			else
				video_modeline=$video_output_xrandr
				dotclock_min=0
				dotclock_min_mame=$dotclock_min
				super_width=3840
				super_width_mame=$super_width
			fi
		else
			video_modeline=$video_output_xrandr
			dotclock_min=25
			dotclock_min_mame=$dotclock_min
			super_width=3840
			super_width_mame=$super_width
		fi
	elif [[ "$video_output" == *"HDMI"* ]] ; then
		term_HDMI=HDMI
		nbr=$(sed 's/[^[:digit:]]//g' <<< "${video_output}")
		video_display=$video_output
		if [ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]; then
			if [ "$Drivers_Name_Nvidia_CHOICE" == "legacy470" ]||[ "$Drivers_Name_Nvidia_CHOICE" == "legacy390" ]||[ "$Drivers_Name_Nvidia_CHOICE" == "legacy340" ]; then	
				video_modeline=$video_output_xrandr
				dotclock_min=25.0
				dotclock_min_mame=$dotclock_min
				super_width=3840
				super_width_mame=$super_width
			else
				video_modeline=$video_output_xrandr
			 	dotclock_min=25.0
				dotclock_min_mame=$dotclock_min
				super_width=3840
				super_width_mame=$super_width
			fi
		else
			video_modeline=$video_output_xrandr
			dotclock_min=25.0
			dotclock_min_mame=$dotclock_min
			super_width=3840
			super_width_mame=$super_width
		fi
	elif [[ "$video_output" == *"VGA"* ]] ; then
		term_VGA=VGA
		nbr=$(sed 's/[^[:digit:]]//g' <<< "${video_output}")
		video_display=$video_output
		if [ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]; then
			if [ "$Drivers_Name_Nvidia_CHOICE" == "legacy470" ]||[ "$Drivers_Name_Nvidia_CHOICE" == "legacy390" ]||[ "$Drivers_Name_Nvidia_CHOICE" == "legacy340" ]; then	
				video_modeline=$video_output_xrandr
				dotclock_min=25.0
				dotclock_min_mame=$dotclock_min
				super_width=3840
				super_width_mame=$super_width
			else
				video_modeline=$video_output_xrandr
				dotclock_min=25.0
				dotclock_min_mame=$dotclock_min
				super_width=3840
				super_width_mame=$super_width
			fi
		else
			video_modeline=$video_output_xrandr
			dotclock_min=0.0
			dotclock_min_mame=$dotclock_min
			super_width=3840
			super_width_mame=$super_width
		fi
	fi
fi

if [ "$CRT_Freq" == "31KHz" ]; then
	dotclock_min=25.0
	dotclock_min_mame=$dotclock_min
fi

#######################################################################
###                 Start of ADVANCED CONFIGURATION                ####
#######################################################################
echo -n -e "                       PRESS ${BLUE}ENTER${NOCOLOR} TO CONTINUE "
read
echo
echo "#######################################################################"
echo "##                                                                   ##"
echo "##                      ADVANCED CONFIGURATION                       ##"
echo "##                                                                   ##"
echo "##                 Experimental display tuning options               ##"
echo "##                                                                   ##"
echo "##                        • Minimum Dotclock                         ##"
echo "##                        • Super-Resolution                         ##"
echo "##                                                                   ##"
echo "##     (If you are unsure about these settings, just press ENTER)    ##"
echo "##                                                                   ##"
echo "#######################################################################"
echo ""
declare -a Default_DT_SR_choice=( "YES" "NO" ) 
for var in "${!Default_DT_SR_choice[@]}" ; do echo "			$((var+1)) : ${Default_DT_SR_choice[$var]}"  | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log; done
echo ""
echo "#######################################################################"
echo "##     Do you want to enter the advanced configuration menu?         ##" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
echo "##                                                                   ##"
echo "##  Recommended only for experienced users or troubleshooting cases. ##"
echo "##       If unsure, it’s best to skip this step and press ENTER.     ##"
echo "#######################################################################"
echo -n "                                  "
read choice_DT_SR
while [[ ! ${choice_DT_SR} =~ ^[1-$((var+1))]$ ]] && [[ "$choice_DT_SR" != "" ]] ; do
	echo -n "Select option 1 to $((var+1)) or ENTER to bypass this configuration:"
	read choice_DT_SR
done

# ---- FIX: ensure DT_SR_Choice is always defined (ENTER or '2' -> NO) ----
DT_SR_Choice="NO"

if [[ -z "$choice_DT_SR" || $choice_DT_SR = "2" ]] ; then 
	echo "                    your choice is : Skipping advanced configuration (using defaults)."  | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
else 
	DT_SR_Choice=${Default_DT_SR_choice[$choice_DT_SR-1]}
echo -e "                    your choice is :${GREEN} $DT_SR_Choice ${NOCOLOR}"  | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
fi


if [ "$DT_SR_Choice" == "YES" ] ; then
	echo -n -e "                       PRESS ${BLUE}ENTER${NOCOLOR} TO CONTINUE "
	read
	echo
	echo ""
	echo "#######################################################################"
	echo "##                                                                   ##"
	echo "##                      ADVANCED CONFIGURATION       1/3             ##" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
	echo "##                                                                   ##"
	echo "##                   Minimum Dotclock Configuration                  ##"
	echo "##                                                                   ##"
	echo "##  This setting defines the lowest pixel clock (MHz) your GPU can   ##"
	echo "##  use when generating video modes. In most cases, this value can   ##"
	echo "##  safely remain at 0 MHz.                                          ##"
	echo "##                                                                   ##"
	echo "##  ⚠️  For AMD GPUs (and most Nvidia Maxwell cards), setting a       ##"
	echo "##  minimum dotclock manually is almost never required.              ##"
	echo "##  The hardware already supports a low dotclock of 0 MHz by design. ##"
	echo "##                                                                   ##"
	echo "##  Only adjust this if you are experiencing launch issues in        ##"
	echo "##  certain emulators or cores (e.g., NES, PC Engine) that display   ##"
	echo "##  a black screen due to unsupported timing.                        ##"
	echo "##                                                                   ##"
	echo "##  If you are unsure, leave this unchanged and just press ENTER.    ##"
	echo "##                                                                   ##"
	echo "#######################################################################"

	echo ""
	declare -a dcm_selector=( "Low - 0" "Mild - 6" "Medium - 12" "High - 25" "CUSTOM")
	for var in "${!dcm_selector[@]}" ; do echo "			$((var+1)) : ${dcm_selector[$var]}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log; done
	echo ""
	echo "#######################################################################"
	echo "##                Choose a minimum dotclock threshold                ##"
	echo "##      This defines the lowest pixel clock allowed for modes.       ##"
	echo "##           Press ENTER to keep the default value of 0 MHz.         ##"
	echo "#######################################################################"
	echo -n "                                  "
	read dcm
	while [[ ! ${dcm} =~ ^[1-$((var+1))]$ ]] && [[ "$dcm" != "" ]] ; do
		echo -n "Select option 1 to $((var+1)) or ENTER to bypass this configuration:"
		read dcm
	done
	if [ -z "$dcm" ] ; then 
		echo -e "                    your choice is :${GREEN} Batocera default minimum dotclock${NOCOLOR}"  | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
	else 
		echo -e "                    your choice is :${GREEN}  ${dcm_selector[$dcm-1]}${NOCOLOR}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
		case $dcm in
			1) 	dotclock_min=0;;
			2) 	dotclock_min=6;;
			3) 	dotclock_min=12;;
			4) 	dotclock_min=25;;
			5) 	echo "#######################################################################"
				echo "##                                                                   ##"
				echo "##         Enter your custom minimum dotclock value (0–25 MHz)       ##"
				echo "##       Only change this if you know your hardware’s limits.        ##"
				echo "##  (Used to restrict the lowest pixel clock allowed by modelines)   ##"
				echo "##         If unsure, use the default value (0 MHz).                 ##"
				echo "##                                                                   ##"
				echo "#######################################################################"
				echo -n "                                  "
				read dotclock_min
				while [[ ! $dotclock_min =~ ^[0-9]+$ || "$dotclock_min" -lt 0 || "$dotclock_min" -gt 25 ]]; do
					echo -n "Enter number between 0 and 25 for dotclock_min: "
					read dotclock_min
				done
				echo -e "                    CUSTOM dotclock_min value = ${GREEN}${dotclock_min}${NOCOLOR}"  | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
			;;
		esac
	fi
	# Check if it was chosen to configurate a particular monitor for M.A.M.E.
monitor_MAME_CHOICE=${monitor_MAME_CHOICE:-NO}
	if [ "$monitor_MAME_CHOICE" = "YES" ] ; then
		echo ""
		echo "#######################################################################"
		echo "##                                                                   ##"
		echo "##                      ADVANCED CONFIGURATION       1b/3            ##" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
		echo "##                                                                   ##"
		echo "##                           MAME MONITOR                            ##"
		echo "##                                                                   ##"
		echo "##  This section adjusts the minimum dotclock used by MAME only.     ##"
		echo "##  In most setups you should leave this unchanged.                   ##"
		echo "##  Change it only if some games/cores launch to a black screen.     ##"
		echo "##                                                                   ##"
		echo "##              ==  MAME minimum dotclock selector  ==               ##"
		echo "##                                                                   ##"
		echo "##  Press ENTER to keep the same dotclock_min as the main monitor.   ##"
		echo "##  If you know what you are doing, select a different value below.  ##"
		echo "##                                                                   ##"
		echo "#######################################################################"
 		echo ""
		declare -a dcm_m_selector=( "Low - 0" "Mild - 6" "Medium - 12" "High - 25" "CUSTOM")
		for var in "${!dcm_m_selector[@]}" ; do echo "			$((var+1)) : ${dcm_m_selector[$var]}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log; done
		echo ""
		echo "#######################################################################"
		echo "##           Select your preferred MAME minimum dotclock value       ##"
		echo "##        (Press ENTER to keep the same as your main monitor)        ##"
		echo "#######################################################################"
		echo -n "                                  "
		read dcm_m
		while [[ ! ${dcm_m} =~ ^[1-$((var+1))]$ ]] && [[ "$dcm_m" != "" ]] ; do
			echo -n "Select option 1 to $((var+1)) or ENTER to bypass this configuration:"
			read dcm_m
		done
		if [ -z "$dcm_m" ] ; then 
			echo -e "                    your choice is :${GREEN} Same as main monitor ($dotclock_min)${NOCOLOR}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
			dotclock_min_mame=$dotclock_min
		else
			echo -e "                    your choice is :${GREEN}  ${dcm_m_selector[$dcm_m-1]}${NOCOLOR}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
			case $dcm_m in
				1)	dotclock_min_mame=0;;
				2)	dotclock_min_mame=6;;
				3)	dotclock_min_mame=12;;
				4)	dotclock_min_mame=25;;
				5) 	echo "#######################################################################"
					echo "##     Enter your custom MAME minimum dotclock value (0–25 MHz)      ##" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
					echo "##     Only change this if you understand your hardware limits.      ##" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
					echo "#######################################################################"
					echo -n "                                  "
					read dotclock_min_mame
					while [[ ! $dotclock_min_mame =~ ^[0-9]+$ || "$dotclock_min_mame" -lt 0 || "$dotclock_min_mame" -gt 25 ]] ; do
						echo -n "Enter number between 0 and 25 for dotclock_min_mame: "
						read dotclock_min_mame
					done
					echo -e "                    CUSTOM dotclock_min_mame value = ${GREEN}${dotclock_min_mame}${NOCOLOR}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
					;;
			esac
		fi
	fi
	#########################################################################
	##                    super-resolution CONFIG                          ##
	#########################################################################
	echo ""
	echo "#######################################################################"
	echo "##                                                                   ##"
	echo "##                      ADVANCED CONFIGURATION       2/3             ##" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
	echo "##                                                                   ##"
	echo "##                     ==  Super-Resolution  ==                      ##"
	echo "##                                                                   ##"
	echo "##      This option defines the virtual width used by Switchres.     ##"
	echo "##     It helps reduce video mode changes between different games.   ##"
	echo "##                                                                   ##"
	echo "##     You can select a default value recommended for your GPU, or   ##"
	echo "##        specify a custom one (advanced users only).                ##"
	echo "##                                                                   ##"
	echo "##     If you are unsure, simply press ENTER to use the default.     ##"
	echo "##                                                                   ##"
	echo "#######################################################################"
	echo ""
	declare -a sr_selector=( "1920 - Intel default" "2560 - amd/ati default" "3840 - nvidia default" "CUSTOM (experimental)")
	for var in "${!sr_selector[@]}" ; do echo "			$((var+1)) : ${sr_selector[$var]}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log; done
	echo ""
	echo "#######################################################################"
	echo "##               Select your preferred super-resolution              ##"
	echo "##          (Press ENTER to skip this configuration step)            ##"
	echo "#######################################################################"
	echo -n "                                  "
	read sr_choice
	while [[ ! ${sr_choice} =~ ^[1-$((var+1))]$ ]] && [[ "$sr_choice" != "" ]] ; do
		echo -n "Select option 1 to $((var+1)) or ENTER to bypass this configuration:"
		read sr_choice
	done
	if [ -z "$sr_choice" ] ; then 
		echo -e "                    your choice is :${GREEN} default super-resolution${NOCOLOR}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
	else
		echo -e "                    your choice is :${GREEN}  ${sr_selector[$sr_choice-1]}${NOCOLOR}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
		case $sr_choice in
			1)	super_width=1920;;
			2)	super_width=2560;;
			3)	super_width=3840;;
			4)	echo "#######################################################################"
				echo "##           Enter a valid number between 0 and 25 MHz               ##"
				echo "##       for your custom super-resolution minimum dotclock.          ##"
				echo "#######################################################################"
				echo -n "                                  "
				read super_width
				while [[ ! $super_width =~ ^[0-9]+$ || "$super_width" -lt 0 ]] ; do
					echo -n "Enter valid number greater than 0 for custom super-resolution:"
					read super_width
				done
				echo -e "                    CUSTOM super-resolution value = ${GREEN}${super_width}${NOCOLOR}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
				;;
		esac
	fi
monitor_MAME_CHOICE=${monitor_MAME_CHOICE:-NO}
	if [ "$monitor_MAME_CHOICE" = "YES" ] ; then
		echo ""
		echo "#######################################################################"
		echo "##                                                                   ##"
		echo "##                      ADVANCED CONFIGURATION       2b/3            ##" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
		echo "##                                                                   ##"
		echo "##                    ==     MAME Super-Resolution     ==             ##"
		echo "##                                                                   ##"
		echo "##     This option defines the vertical super-resolution used by      ##"
		echo "##     MAME when generating dynamic modelines for arcade games.       ##"
		echo "##     You can choose a recommended preset or define your own         ##"
		echo "##     custom value for testing and fine-tuning purposes.             ##"
		echo "##                                                                   ##"
		echo "##     In most cases, the default value for your GPU is optimal.      ##"
		echo "##     If you are unsure what this means, simply press ENTER to       ##"
		echo "##     keep the default setting.                                      ##"
		echo "##                                                                   ##"
		echo "#######################################################################"
		echo ""
		declare -a sr_m_selector=( "1920 - Intel default" "2560 - amd/ati/ default" "3840 - nvidia default" "Same as main monitor" "CUSTOM (experimental)")
		for var in "${!sr_m_selector[@]}" ; do echo "			$((var+1)) : ${sr_m_selector[$var]}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log; done
		echo ""
		echo "#######################################################################"
		echo "##     Choose a MAME super-resolution preset, or CUSTOM (width)      ##"
		echo "##           Press ENTER to keep the default for your GPU            ##"
		echo "#######################################################################"
		echo -n "                                  "
		read sr_m_choice
		while [[ ! ${sr_m_choice} =~ ^[1-$((var+1))]$ ]] && [[ "$sr_m_choice" != "" ]] ; do
			echo -n "Select option 1 to $((var+1)) or ENTER to bypass this configuration:"
			read sr_m_choice
		done
		if [ -z "$sr_m_choice" ] ; then 
			echo -e "                    your choice is :${GREEN} MAME default super-resolution${NOCOLOR}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
		else
			echo -e "                    your choice is :${GREEN}  ${sr_m_selector[$sr_m_choice-1]}${NOCOLOR}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
			case $sr_m_choice in
				1)	super_width_mame=1920;;
				2)	super_width_mame=2560;;
				3)	super_width_mame=3840;;
				4)	super_width_mame=$super_width;;
				5)	echo "#######################################################################"
					echo "##             Select your custom MAME super_resolution              ##"
					echo "#######################################################################"
					echo -n "                                  "
					read super_width_mame
					while [[ ! $super_width_mame =~ ^[0-9]+$ || "$super_width_mame" -lt 0 ]] ; do
						echo -n "Enter valid number greater than 0 for custom super-resolution"
						read super_width_mame
					done
					echo -e "                    CUSTOM MAME super-resolution value = ${GREEN}${super_width_mame}${NOCOLOR}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
					;;
			esac

		fi
	fi
fi
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
	elif [ "$Drivers_Name_Nvidia_CHOICE" == "legacy470" ]; then
		sed -e 's/.*nvidia-driver=.*/nvidia-driver=legacy470/'  -e 's/.*amdgpu=.*/#amdgpu=true/'  	/boot/batocera-boot.conf > /boot/batocera-boot.conf.tmp
	elif [ "$Drivers_Name_Nvidia_CHOICE" == "legacy390" ]; then
		sed -e 's/.*nvidia-driver=.*/nvidia-driver=legacy390/' -e 's/.*amdgpu=.*/#amdgpu=true/' /boot/batocera-boot.conf > /boot/batocera-boot.conf.tmp
        elif [ "$Drivers_Name_Nvidia_CHOICE" == "legacy340" ]; then
		sed -e 's/.*nvidia-driver=.*/nvidia-driver=legacy340/' -e 's/.*amdgpu=.*/#amdgpu=true/' /boot/batocera-boot.conf > /boot/batocera-boot.conf.tmp
	else
		echo "problems of Nvidia driver name"
	fi	
else
	if [ "$Drivers_Nvidia_CHOICE" == "NOUVEAU" ]&&([ "$Version_of_batocera" == "v39" ]||[ "$Version_of_batocera" == "v40" ]||[ "$Version_of_batocera" == "v41" ]||[ "$Version_of_batocera" == "v42" ]); then
		sed -e 's/.*nvidia-driver=.*/nvidia-driver=false/' -e 's/.*amdgpu=.*/#amdgpu=true/' 	 	/boot/batocera-boot.conf > /boot/batocera-boot.conf.tmp
	else
		if [ "$TYPE_OF_CARD" == "AMD/ATI" ]&&([ "$Version_of_batocera" == "v39" ]||[ "$Version_of_batocera" == "v40" ]||[ "$Version_of_batocera" == "v41" ]||[ "$Version_of_batocera" == "v42" ]); then

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

# Make sure /boot is writable; harmless if already rw
mount -o remount,rw /boot 2>/dev/null || true

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

#############################################################################
## Copy syslinux for EFI and additional legacy paths (only if present)
#############################################################################

# We mirror the generated file to these directories when they exist.
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
#############################################################################
## Build/copy syslinux.cfg for your boot layout (v42-safe) END			   ##
#############################################################################

#############################################################################
##            Single 20-modesetting.conf for AMD (v42-safe) START          ##
#############################################################################

# First time using the script backup the 20-amdgpu.conf & 20-radeon.conf
if [ ! -f "/etc/X11/xorg.conf.d/20-amdgpu.conf.bak" ];then
	cp /etc/X11/xorg.conf.d/20-amdgpu.conf /etc/X11/xorg.conf.d/20-amdgpu.conf.bak
fi

if [ ! -f "/etc/X11/xorg.conf.d/20-radeon.conf.bak" ];then
	cp /etc/X11/xorg.conf.d/20-radeon.conf /etc/X11/xorg.conf.d/20-radeon.conf.bak
fi 

# Now delete the files so they are no longer loaded during boot
for f in /etc/X11/xorg.conf.d/20-radeon.conf /etc/X11/xorg.conf.d/20-amdgpu.conf; do
  [ -e "$f" ] && rm -f "$f"
done
 
# Copy over the new 20-modesetting.conf & set correct file permission
cp /userdata/system/Batocera-CRT-Script/etc_configs/Monitors_config/20-modesetting.conf /etc/X11/xorg.conf.d/20-modesetting.conf
chmod 644 /etc/X11/xorg.conf.d/20-modesetting.conf

#############################################################################
##            Single 20-modesetting.conf for AMD (v42-safe) END            ##
#############################################################################

##################################################################################################
python_directory=$(find /usr/lib/ -maxdepth 1 -type d -name "python*" -exec basename {} \; -quit)
new_path1="/usr/lib/${python_directory}/site-packages/configgen/"
# Check if the file exists and make a backup
if [ ! -f "${new_path1}emulatorlauncher.py.bak" ]; then
    echo "Backing up emulatorlauncher.py"
    cp "${new_path1}emulatorlauncher.py" 	"${new_path1}emulatorlauncher.py.bak"
fi
new_path2="/usr/lib/${python_directory}/site-packages/configgen/utils/"
if [ ! -f "/${new_path2}videoMode.py.bak" ];then
	cp "${new_path2}videoMode.py" 		"${new_path2}videoMode.py.bak"
fi
##################################################################################################



## Only for Batocera >= V32
case $Version_of_batocera in
 	v39)
		if [ "$ZFEbHVUE" == "1" ]; then

			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/Configgen/emulatorlauncher.py_ZFEbHVUE	"${new_path1}emulatorlauncher.py"
			chmod 755  "${new_path1}emulatorlauncher.py"
			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/Configgen/VideoMode.py_ZFEbHVUE 		"${new_path2}videoMode.py"
			chmod 755 "${new_path2}videoMode.py"

			if [ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]; then
			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/batocera-resolution-v38_Nvidia_driver_MYZAR_ZFEbHVUE 	/usr/bin/batocera-resolution
			else
			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/batocera-resolution-v38_MYZAR_ZFEbHVUE 			/usr/bin/batocera-resolution
			fi
			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/emulationstation-standalone-v38_ZFEbHVUE 		/usr/bin/emulationstation-standalone

		else
			cp "${new_path1}emulatorlauncher.py.bak" 	"${new_path1}emulatorlauncher.py"
			cp "${new_path2}videoMode.py.bak" 		"${new_path2}videoMode.py"

			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/batocera-resolution-v38_Myzar	 	/usr/bin/batocera-resolution
			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/emulationstation-standalone-v38		/usr/bin/emulationstation-standalone
			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/batocera-checkmode_Myzar			/usr/bin/batocera-checkmode
			chmod 755 /usr/bin/batocera-checkmode


		fi

		chmod 755 /usr/bin/batocera-resolution 
		chmod 755 /usr/bin/emulationstation-standalone
		sed -e "s/\[monitor-name\]/$monitor_name_MAME/g" -e "s/\[super_width\]/$super_width/g" -e "s/\[dotclock_min_value\]/$dotclock_min/g"  /userdata/system/Batocera-CRT-Script/etc_configs/switchres.ini-generic-v36 > /etc/switchres.ini
		sed -i "s/.*interlace_force_even   .*/        interlace_force_even      $IFE/" /etc/switchres.ini
  		chmod 755 /etc/switchres.ini

		cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/get_monitorRange  /usr/bin/get_monitorRange
		chmod 755 /usr/bin/get_monitorRange

	;;
	v40)
		if [ "$ZFEbHVUE" == "1" ]; then

			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/Configgen/emulatorlauncher.py_ZFEbHVUE	"${new_path1}emulatorlauncher.py"
			chmod 755  "${new_path1}emulatorlauncher.py"
			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/Configgen/VideoMode.py-v40_ZFEbHVUE	"${new_path2}videoMode.py"
			chmod 755 "${new_path2}videoMode.py"

			if [ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]; then
			#cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/batocera-resolution-v40_Nvidia_driver_MYZAR_ZFEbHVUE 			/usr/bin/batocera-resolution
			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/batocera-resolution-v40_Nvidia_driver_MYZAR_ZFEbHVUE-MultiScreen 	/usr/bin/batocera-resolution
			else
			#cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/batocera-resolution-v40_MYZAR_ZFEbHVUE 			/usr/bin/batocera-resolution
			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/batocera-resolution-v40_MYZAR_ZFEbHVUE-MultiScreen	/usr/bin/batocera-resolution

			fi
			#cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/emulationstation-standalone-v40_ZFEbHVUE 		/usr/bin/emulationstation-standalone
			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/emulationstation-standalone-v40_ZFEbHVUE-MultiScreen	/usr/bin/emulationstation-standalone

		else
			cp "${new_path1}emulatorlauncher.py.bak" 	"${new_path1}emulatorlauncher.py"
			cp "${new_path2}videoMode.py.bak" 		"${new_path2}videoMode.py"

			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/batocera-resolution-v40_Myzar	 	/usr/bin/batocera-resolution
			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/emulationstation-standalone-v40		/usr/bin/emulationstation-standalone
			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/batocera-checkmode_Myzar			/usr/bin/batocera-checkmode
			chmod 755 /usr/bin/batocera-checkmode


		fi

		chmod 755 /usr/bin/batocera-resolution 
		chmod 755 /usr/bin/emulationstation-standalone
		sed -e "s/\[monitor-name\]/$monitor_name_MAME/g" -e "s/\[super_width\]/$super_width/g" -e "s/\[dotclock_min_value\]/$dotclock_min/g"  /userdata/system/Batocera-CRT-Script/etc_configs/switchres.ini-generic-v36 > /etc/switchres.ini
		sed -i "s/.*interlace_force_even   .*/        interlace_force_even      $IFE/" /etc/switchres.ini
  		chmod 755 /etc/switchres.ini

		cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/get_monitorRange  /usr/bin/get_monitorRange
		chmod 755 /usr/bin/get_monitorRange

	;;

	v41)
		if [ "$ZFEbHVUE" == "1" ]; then

			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/Configgen/emulatorlauncher.py_v41_ZFEbHVUE	"${new_path1}emulatorlauncher.py"
			chmod 755  "${new_path1}emulatorlauncher.py"
			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/Configgen/VideoMode.py-v41_ZFEbHVUE		"${new_path2}videoMode.py"
			chmod 755 "${new_path2}videoMode.py"

			if [ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]; then
			#cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/batocera-resolution-v40_Nvidia_driver_MYZAR_ZFEbHVUE 			/usr/bin/batocera-resolution
			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/batocera-resolution-v41_Nvidia_driver_MYZAR_ZFEbHVUE-MultiScreen 	/usr/bin/batocera-resolution
			else
			#cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/batocera-resolution-v40_MYZAR_ZFEbHVUE 			/usr/bin/batocera-resolution
			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/batocera-resolution-v41_MYZAR_ZFEbHVUE-MultiScreen	/usr/bin/batocera-resolution

			fi
			#cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/emulationstation-standalone-v40_ZFEbHVUE 		/usr/bin/emulationstation-standalone
			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/emulationstation-standalone-v41_ZFEbHVUE-MultiScreen	/usr/bin/emulationstation-standalone

		else
			cp "${new_path1}emulatorlauncher.py.bak" 	"${new_path1}emulatorlauncher.py"
			cp "${new_path2}videoMode.py.bak" 		"${new_path2}videoMode.py"

			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/batocera-resolution-v40_Myzar	 	/usr/bin/batocera-resolution
			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/emulationstation-standalone-v40		/usr/bin/emulationstation-standalone
			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/batocera-checkmode_Myzar			/usr/bin/batocera-checkmode
			chmod 755 /usr/bin/batocera-checkmode


		fi

		chmod 755 /usr/bin/batocera-resolution 
		chmod 755 /usr/bin/emulationstation-standalone
		sed -e "s/\[monitor-name\]/$monitor_name_MAME/g" -e "s/\[super_width\]/$super_width/g" -e "s/\[dotclock_min_value\]/$dotclock_min/g"  /userdata/system/Batocera-CRT-Script/etc_configs/switchres.ini-generic-v36 > /etc/switchres.ini
		sed -i "s/.*interlace_force_even   .*/        interlace_force_even      $IFE/" /etc/switchres.ini
  		chmod 755 /etc/switchres.ini

		cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/get_monitorRange  /usr/bin/get_monitorRange
		chmod 755 /usr/bin/get_monitorRange

                #only for V41. Xemu from V42 to fixe a Mesa isse with AAMD
                cp -r /userdata/system/Batocera-CRT-Script/UsrBin_configs/xemu_v41/usr /	
		chmod 755 /usr/bin/xemu

	;;

	v42)
		if [ "$ZFEbHVUE" == "1" ]; then

			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/Configgen/emulatorlauncher.py_v42_ZFEbHVUE	"${new_path1}emulatorlauncher.py"
			chmod 755  "${new_path1}emulatorlauncher.py"
			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/Configgen/VideoMode.py-v42_ZFEbHVUE		"${new_path2}videoMode.py"
			chmod 755 "${new_path2}videoMode.py"

			if [ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]; then
			#cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/batocera-resolution-v40_Nvidia_driver_MYZAR_ZFEbHVUE 			/usr/bin/batocera-resolution
			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/batocera-resolution-v42_Nvidia_driver_MYZAR_ZFEbHVUE-MultiScreen 	/usr/bin/batocera-resolution
			else
			#cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/batocera-resolution-v40_MYZAR_ZFEbHVUE 			/usr/bin/batocera-resolution
			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/batocera-resolution-v42_MYZAR_ZFEbHVUE-MultiScreen	/usr/bin/batocera-resolution

			fi
			#cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/emulationstation-standalone-v40_ZFEbHVUE 		/usr/bin/emulationstation-standalone
			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/emulationstation-standalone-v42_ZFEbHVUE-MultiScreen	/usr/bin/emulationstation-standalone

		else
			cp "${new_path1}emulatorlauncher.py.bak" 	"${new_path1}emulatorlauncher.py"
			cp "${new_path2}videoMode.py.bak" 		"${new_path2}videoMode.py"

			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/batocera-resolution-v40_Myzar	 	/usr/bin/batocera-resolution
			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/emulationstation-standalone-v40		/usr/bin/emulationstation-standalone
			cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/batocera-checkmode_Myzar			/usr/bin/batocera-checkmode
			chmod 755 /usr/bin/batocera-checkmode


		fi

		chmod 755 /usr/bin/batocera-resolution 
		chmod 755 /usr/bin/emulationstation-standalone
		sed -e "s/\[monitor-name\]/$monitor_name_MAME/g" -e "s/\[super_width\]/$super_width/g" -e "s/\[dotclock_min_value\]/$dotclock_min/g"  /userdata/system/Batocera-CRT-Script/etc_configs/switchres.ini-generic-v36 > /etc/switchres.ini
		sed -i "s/.*interlace_force_even   .*/        interlace_force_even      $IFE/" /etc/switchres.ini
 		chmod 755 /etc/switchres.ini

		cp /userdata/system/Batocera-CRT-Script/UsrBin_configs/get_monitorRange  /usr/bin/get_monitorRange
		chmod 755 /usr/bin/get_monitorRange

                #only for V41. Xemu from V42 to fixe a Mesa isse with AAMD
                #cp -r /userdata/system/Batocera-CRT-Script/UsrBin_configs/xemu_v41/usr /	
		#chmod 755 /usr/bin/xemu

	;;




	*)
		echo "PROBLEM OF VERSION"
		exit 1;
	;;
esac

cp /etc/switchres.ini /etc/switchres.ini.bak

#stop ES
if [ ! -f "/usr/bin/stop" ];then
	touch /usr/bin/stop
	echo "#!/bin/bash" 				>> /usr/bin/stop
	echo  "/etc/init.d/S31emulationstation stop" 	>> /usr/bin/stop
	chmod 755 /usr/bin/stop
fi
#start ES
if [ ! -f "/usr/bin/start" ];then
	touch /usr/bin/start
	echo "#!/bin/bash" 				>> /usr/bin/start
	echo  "/etc/init.d/S31emulationstation start" 	>> /usr/bin/start
	chmod 755 /usr/bin/start
fi


#######################################################################################
## Remove Beta name from splash screen if using a beta.
#######################################################################################
if [ -f "/usr/share/batocera/splash/splash.srt" ];then
	mv /usr/share/batocera/splash/splash.srt /usr/share/batocera/splash/splash.srt.bak
fi
#######################################################################################
## make splash screen rotation if using tate mode (right or left).
#######################################################################################
if [ ! -f "/usr/share/batocera/splash/boot-logo.png.bak" ]; then
	cp /usr/share/batocera/splash/boot-logo.png /usr/share/batocera/splash/boot-logo.png.bak
fi
cp /userdata/system/Batocera-CRT-Script/Boot_logos/boot-logo.png /usr/share/batocera/splash/boot-logo.png 
if [ "$display_rotate" == "right" ];then

	cp /userdata/system/Batocera-CRT-Script/Boot_logos/boot-logo_90.png /usr/share/batocera/splash/boot-logo.png 
fi
if [ "$display_rotate" == "inverted" ];then

	cp /userdata/system/Batocera-CRT-Script/Boot_logos/boot-logo_180.png /usr/share/batocera/splash/boot-logo.png 
fi
if  [ "$display_rotate" == "left" ]; then
	cp /userdata/system/Batocera-CRT-Script/Boot_logos/boot-logo_270.png /usr/share/batocera/splash/boot-logo.png  
fi

#######################################################################################
#######################################################################################
##         USB Arcade Encoders (multiple choices) for Arcade cabinet 
#######################################################################################
#######################################################################################

echo ""
echo "#######################################################################"
echo "##     USB Arcade Encoder(s) :  Multiple choices are possible        ##"
echo "#######################################################################"
declare -a Encoder_inputs=\($(ls -1 /dev/input/by-id/ | tr '\012' ' ' | sed -e 's, ," ",g' -e 's,^,",' -e 's," "$,",')\)
for var in "${!Encoder_inputs[@]}"; do
  echo "			$((var+1)) : ${Encoder_inputs[$var]}"
done
echo "                        0 : Exit for USB Arcade Encoder(s)                   "
echo "#######################################################################"
echo "##                                                                   ##"
echo "##                   Select your USB Arcade Encoder(s)               ##"
echo "##                                                                   ##"
echo "##   You can select one or multiple encoders by typing their numbers ##"
echo "##   separated by commas or spaces (for example: 1 2 3).             ##"
echo "##                                                                   ##"
echo "##   If you do not have any USB Arcade Encoders, or if you want      ##"
echo "##   Batocera to handle encoder setup automatically, simply press    ##"
echo "##   ENTER or type 0 to skip this step.                              ##"
echo "##                                                                   ##"
echo "##                     RECOMMENDED: PRESS 0 OR ENTER                 ##"
echo "##                                                                   ##"
echo "#######################################################################"
echo -n "                                  "
read Encoder_choice

# Normalize input: commas → spaces; trim extra spaces
Encoder_choice="$(echo "${Encoder_choice:-}" | sed -e 's/,/ /g' -e 's/[[:space:]]\+/ /g' -e 's/^ //; s/ $//')"

if [ -z "$Encoder_choice" ] || [ "x$Encoder_choice" = "x0" ]; then
  echo "No USB Arcade encoder(s) has been chosen"
else
  RUNTIME_DIR="/userdata/system/configs/xarcade2jstick"
  LEGACY_DIR="/usr/share/batocera/datainit/system/configs/xarcade2jstick"

  # Ensure runtime directory exists
  mkdir -p "$RUNTIME_DIR"

  for i in $Encoder_choice; do
    # Guard: numeric and within bounds
    case "$i" in
      ''|*[!0-9]*) echo "Skipping invalid selection: $i"; continue ;;
    esac
    idx=$((i-1))
    if [ "$idx" -lt 0 ] || [ "$idx" -ge "${#Encoder_inputs[@]}" ]; then
      echo "Skipping out-of-range selection: $i"
      continue
    fi

    name="${Encoder_inputs[$idx]}"
    echo -e "                    your choice is : ${name}"

    # Create marker in runtime overlay
    touch "$RUNTIME_DIR/$name" 2>/dev/null || echo "Warning: could not create $RUNTIME_DIR/$name"

    # Optionally also write to legacy tree if it exists and is writable
    if [ -d "$LEGACY_DIR" ] && touch "$LEGACY_DIR/.writable_test" 2>/dev/null; then
      rm -f "$LEGACY_DIR/.writable_test"
      mkdir -p "$LEGACY_DIR"
      touch "$LEGACY_DIR/$name" 2>/dev/null || true
    fi
  done
fi




#######################################################################################
# Select the calibration resolution for your GunCon II
#######################################################################################

echo "####################################################################################"
echo "##        Configure the resolution for calibrating your GunCon2 lightgun          ##" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
echo "##                                                                                ##"
echo "##   (Recommended Default)                                                        ##"
echo "##     • For AMD/ATI or NVIDIA (Maxwell and newer):  use 320x240 @ 60 Hz          ##"
echo "##     • For older NVIDIA GPUs with dotclock_min = 25 MHz:  try 640x480 @ 60 Hz   ##"
echo "##                                                                                ##"
echo "##   Experimental Mode                                                            ##"
echo "##     • You can test custom resolutions such as 640x480 @ 60 Hz                  ##"
echo "##       or 768x576 @ 50 Hz to see what works best on your setup.                 ##"
echo "##     • If you wish to experiment, choose YES below.                             ##"
echo "##                                                                                ##"
printf "%b\n" "##   ${RED}Warning:${NOCOLOR}                                                                     ##"
echo "##   It is strongly recommended to keep the default value unless you              ##"
echo "##   fully understand how these resolutions affect calibration.                   ##"
echo "##                                                                                ##"
printf "%b\n" "##   ${GREEN}Note:${NOCOLOR}                                                                        ##"
echo "##   Calibration results are generally most accurate at 320x240p.                 ##"
echo "##                                                                                ##"
echo "##   Press ENTER to use the default calibration resolution (320x240 @ 60 Hz).     ##"
echo "####################################################################################"
echo ""
declare -a Calibration_Guncon2_choice=( "NO" "YES" )
for var in "${!Calibration_Guncon2_choice[@]}" ; do echo "			$((var+1)) : ${Calibration_Guncon2_choice[$var]}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log; done
echo ""
echo "#######################################################################"
echo "##                         Make your choice                          ##"
echo "#######################################################################"
echo -n "                                  "
read choice_Calibration_Guncon2

# Handle invalid input or default value (ENTER)
while [[ ! ${choice_Calibration_Guncon2} =~ ^[1-$((var+1))]$ ]] && [[ -n ${choice_Calibration_Guncon2} ]]; do
	echo -n "Select option 1 to $((var+1)) or press ENTER for default: "
	read choice_Calibration_Guncon2
done

if [ -z "$choice_Calibration_Guncon2" ] || [ "$choice_Calibration_Guncon2" == "1" ]; then
	echo -e "                    Your choice is: ${GREEN}Bypass with default resolution (320x240@60Hz)${NOCOLOR}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log
	# Set default resolution variables
	Guncon2_x=320
	Guncon2_y=240
	Guncon2_freq=60
	Guncon2_res=($Guncon2_x"x"$Guncon2_y)
else
	echo -e "                    Your choice is: ${GREEN}Custom resolution setup${NOCOLOR}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log

	# Custom horizontal resolution
	echo "###############################################################################"
	echo "##      Select your custom horizontal resolution for Guncon2 calibration     ##"
	echo "###############################################################################"
	echo -n "                                  "
	read Guncon2_x
	while [[ ! $Guncon2_x =~ ^[0-9]+$ || "$Guncon2_x" -lt 0 ]]; do
		echo -n "Enter a valid number greater than 0 for Guncon2_x: "
		read Guncon2_x
	done
	echo -e "                    CUSTOM Guncon2_x Horizontal resolution  = ${GREEN}${Guncon2_x}${NOCOLOR}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log

	# Custom vertical resolution
	echo "###############################################################################"
	echo "##      Select your custom vertical resolution for Guncon2 calibration       ##"
	echo "###############################################################################"
	echo -n "                                  "
	read Guncon2_y
	while [[ ! $Guncon2_y =~ ^[0-9]+$ || "$Guncon2_y" -lt 0 ]]; do
		echo -n "Enter a valid number greater than 0 for Guncon2_y: "
		read Guncon2_y
	done
	echo -e "                    CUSTOM Guncon2_y Vertical resolution  = ${GREEN}${Guncon2_y}${NOCOLOR}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log

	# Custom frequency
	echo "###############################################################################"
	echo "##      Select your custom frequency resolution for Guncon2 calibration      ##"
	echo "###############################################################################"
	echo -n "                                  "
	read Guncon2_freq
	while [[ ! $Guncon2_freq =~ ^[0-9]+$ || "$Guncon2_freq" -lt 0 ]]; do
		echo -n "Enter a valid number greater than 0 for Guncon2_freq: "
		read Guncon2_freq
	done
	echo -e "                    CUSTOM frequency resolution  = ${GREEN}${Guncon2_freq}${NOCOLOR}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log

	# Set custom resolution
	Guncon2_res=($Guncon2_x"x"$Guncon2_y)
fi



echo ""
echo "#######################################################################"
echo "##                                                                   ##"
echo "##                   BEFORE PRESSING ENTER, PLEASE READ              ##"
echo "##                                                                   ##"
echo "##  The authors of this script take no responsibility for any damage ##"
echo "##               caused to your CRT or connected hardware.           ##"
echo "##                                                                   ##"
echo "##   Before continuing, make sure you have properly connected your   ##"
echo "##   display cables and verified that your setup supports 15 kHz.    ##"
echo "##                                                                   ##"
echo "##        Always power off your system safely before reconnecting    ##"
echo "##             or adjusting video cables and CRT displays.           ##"
echo "##                                                                   ##"
echo "##          When you’re ready, reboot Batocera and enjoy your        ##"
echo "##                        15 kHz experience!                         ##"
echo "##                                                                   ##"
echo "#######################################################################"
echo ""
echo -n -e "                       PRESS ${BLUE}ENTER${NOCOLOR} TO FINISH "
read 

#######################################################################################
# Create files for adjusting your CRT
#######################################################################################
cp -a /userdata/system/Batocera-CRT-Script/Geometry_modeline/crt/ /userdata/roms/
cp /userdata/system/Batocera-CRT-Script/Geometry_modeline/es_systems_crt.cfg /userdata/system/configs/emulationstation/es_systems_crt.cfg
cp /userdata/system/Batocera-CRT-Script/Geometry_modeline/CRT.png /usr/share/emulationstation/themes/es-theme-carbon/art/consoles/CRT.png
cp /userdata/system/Batocera-CRT-Script/Geometry_modeline/CRT.svg /usr/share/emulationstation/themes/es-theme-carbon/art/logos/CRT.svg
chmod 755 /userdata/roms/crt/es_adjust_tool.sh
chmod 755 /userdata/roms/crt/geometry.sh
chmod 755 /userdata/system/Batocera-CRT-Script/Geometry_modeline/es_tool.sh
chmod 755 /userdata/system/Batocera-CRT-Script/Geometry_modeline/geometry.sh
chmod 0644 /userdata/roms/crt/es_adjust_tool.sh.keys
chmod 0644 /userdata/roms/crt/geometry.sh.keys
chmod 755 /userdata/roms/crt/grid_tool.sh
chmod 755 /userdata/system/Batocera-CRT-Script/Geometry_modeline/grid_tool.sh
chmod 0644 /userdata/roms/crt/grid_tool.sh.keys

#######################################################################################
# Create Mode Switcher for HD/CRT Mode switching
#######################################################################################
if [ -f "/userdata/system/Batocera-CRT-Script/Geometry_modeline/crt/mode_switcher.sh" ]; then
    # Ensure main script exists and is executable
    if [ -f "/userdata/system/Batocera-CRT-Script/Geometry_modeline/mode_switcher.sh" ]; then
        chmod 755 /userdata/system/Batocera-CRT-Script/Geometry_modeline/mode_switcher.sh
    fi
    
    # Copy mode switcher wrapper to CRT Tools (wrapper launches main script in xterm)
    cp /userdata/system/Batocera-CRT-Script/Geometry_modeline/crt/mode_switcher.sh /userdata/roms/crt/mode_switcher.sh
    chmod 755 /userdata/roms/crt/mode_switcher.sh
    # Copy .keys file for controller support
    if [ -f "/userdata/system/Batocera-CRT-Script/Geometry_modeline/crt/mode_switcher.sh.keys" ]; then
        cp /userdata/system/Batocera-CRT-Script/Geometry_modeline/crt/mode_switcher.sh.keys /userdata/roms/crt/mode_switcher.sh.keys
        chmod 644 /userdata/roms/crt/mode_switcher.sh.keys
    fi
    
    # Copy gamelist.xml to make Mode Switcher visible in EmulationStation
    if [ -f "/userdata/system/Batocera-CRT-Script/Geometry_modeline/crt/gamelist.xml" ]; then
        cp /userdata/system/Batocera-CRT-Script/Geometry_modeline/crt/gamelist.xml /userdata/roms/crt/gamelist.xml
        chmod 644 /userdata/roms/crt/gamelist.xml
    fi
    
    # Create mode backup directories
    mkdir -p /userdata/Batocera-CRT-Script-Backup/mode_backups/hd_mode
    mkdir -p /userdata/Batocera-CRT-Script-Backup/mode_backups/crt_mode
    mkdir -p /userdata/Batocera-CRT-Script-Backup/mode_backups/hd_mode/boot_configs
    mkdir -p /userdata/Batocera-CRT-Script-Backup/mode_backups/hd_mode/emulator_configs
    mkdir -p /userdata/Batocera-CRT-Script-Backup/mode_backups/hd_mode/video_settings
    mkdir -p /userdata/Batocera-CRT-Script-Backup/mode_backups/crt_mode/boot_configs
    mkdir -p /userdata/Batocera-CRT-Script-Backup/mode_backups/crt_mode/emulator_configs
    mkdir -p /userdata/Batocera-CRT-Script-Backup/mode_backups/crt_mode/video_settings
    
    echo "Mode Switcher installed successfully."
else
    echo "Mode Switcher script not found. Skipping installation."
fi

#######################################################################################
# Create geometryForVideomodes.sh  for adjusting resoltuion in videomodes.conf for your CRT
#######################################################################################

#cp Batocera-CRT-Script/Geometry_modeline/crt/geometryForVideomodes.sh /userdata/roms/crt/geometryForVideomodes.sh
#chmod 755 /userdata/roms/crt/geometryForVideomodes.sh

#######################################################################################
# Create GunCon2 LUA plugin for GroovyMame for V36, V37 and V38
#######################################################################################
## if the folder doesn't exist, it will be created now
if [ ! -d "/usr/bin/mame/plugins/gunlight" ];then
	mkdir /usr/bin/mame/plugins/gunlight
fi
if ([ "$Version_of_batocera" == "v39" ]||[ "$Version_of_batocera" == "v40" ]||[ "$Version_of_batocera" == "v41" ]||[ "$Version_of_batocera" == "v42" ]); then
	cp /userdata/system/Batocera-CRT-Script/GunCon2/gunlight/gunlight_menu.lua /usr/bin/mame/plugins/gunlight/gunlight_menu.lua
	cp /userdata/system/Batocera-CRT-Script/GunCon2/gunlight/gunlight_save.lua /usr/bin/mame/plugins/gunlight/gunlight_save.lua
	cp /userdata/system/Batocera-CRT-Script/GunCon2/gunlight/init.lua /usr/bin/mame/plugins/gunlight/init.lua
	cp /userdata/system/Batocera-CRT-Script/GunCon2/gunlight/plugin.json /usr/bin/mame/plugins/gunlight/plugin.json
	chmod 644 /usr/bin/mame/plugins/gunlight/gunlight_menu.lua
	chmod 644 /usr/bin/mame/plugins/gunlight/gunlight_save.lua
	chmod 644 /usr/bin/mame/plugins/gunlight/init.lua
	chmod 644 /usr/bin/mame/plugins/gunlight/plugin.json
fi

#######################################################################################
# Create GunCon2 shader for V36, V37 and v38
#######################################################################################
## if the folder doesn't exist, it will be created now
if [ ! -d "/usr/share/batocera/shaders/configs/lightgun-shader" ];then
	mkdir /usr/share/batocera/shaders/configs/lightgun-shader
fi
	cp /userdata/system/Batocera-CRT-Script/GunCon2/shader/lightgun-shader/rendering-defaults.yml /usr/share/batocera/shaders/configs/lightgun-shader/rendering-defaults.yml
	chmod 644 /usr/share/batocera/shaders/configs/lightgun-shader/rendering-defaults.yml
	cp /userdata/system/Batocera-CRT-Script/GunCon2/shader/misc/image-adjustment_lgun.slangp /usr/share/batocera/shaders/misc/image-adjustment_lgun.slangp
	cp /userdata/system/Batocera-CRT-Script/GunCon2/shader/misc/shaders/image-adjustment_lgun.slang /usr/share/batocera/shaders/misc/shaders/image-adjustment_lgun.slang
	chmod 644 /usr/share/batocera/shaders/misc/image-adjustment_lgun.slangp
	chmod 644 /usr/share/batocera/shaders/misc/shaders/image-adjustment_lgun.slang

	if [ ! -f "/etc/udev/rules.d/99-guncon.rules.bak" ];then                                                           
		cp /etc/udev/rules.d/99-guncon.rules /etc/udev/rules.d/99-guncon.rules.bak                       
	fi
 
	cp /userdata/system/Batocera-CRT-Script/GunCon2/99-guncon.rules-generic /etc/udev/rules.d/99-guncon.rules

        if [ ! -f "/usr/bin/guncon2_calibrate.sh.bak" ];then                                                           
		cp /usr/bin/guncon2_calibrate.sh /usr/bin/guncon2_calibrate.sh.bak                      
	fi

	sed -e "s/\[guncon2_x\]/$Guncon2_x/g" -e "s/\[guncon2_y\]/$Guncon2_y/g" -e "s/\[guncon2_f\]/$Guncon2_freq/g" -e "s/\[guncon2_res\]/$Guncon2_res/g" \
		/userdata/system/Batocera-CRT-Script/GunCon2/guncon2_calibrate.sh-generic  > /usr/bin/guncon2_calibrate.sh
        chmod 755 /usr/bin/guncon2_calibrate.sh


	if [ ! -f "/usr/bin/calibrate.py.bak" ];then                                                           
		cp /usr/bin/calibrate.py /usr/bin/calibrate.py.bak                      
	fi
	if [ "$ES_rotation" == "NORMAL" ] || [ "$ES_rotation" == "INVERTED" ]; then	
		sed -e "s/\[guncon2_x\]/$Guncon2_x/g" -e "s/\[guncon2_y\]/$Guncon2_y/g"  -e "s/\[guncon2_res\]/$Guncon2_res/g" \
		       	/userdata/system/Batocera-CRT-Script/GunCon2/calibrate.py-generic   > /usr/bin/calibrate.py
	else
		sed -e "s/\[guncon2_y\]/$Guncon2_x/g" -e "s/\[guncon2_x\]/$Guncon2_y/g"  -e "s/\[guncon2_res\]/$Guncon2_res/g" \
		       	/userdata/system/Batocera-CRT-Script/GunCon2/calibrate.py-generic   > /usr/bin/calibrate.py
	fi
	chmod 755 /usr/bin/calibrate.py

#######################################################################################
# Add VNC server files to /lib & /usr/lib for v41
#######################################################################################
#mv /lib/libcrypt.so.1 /lib/libcrypt.so.1.bak
cp /userdata/system/Batocera-CRT-Script/install-vnc_server_batocera/libcrypt.so.1 /lib/libcrypt.so.1 
cp /userdata/system/Batocera-CRT-Script/install-vnc_server_batocera/libcrypt.so.1 /usr/lib/libcrypt.so.1
cp /userdata/system/Batocera-CRT-Script/install-vnc_server_batocera/libvncclient.so.1 /usr/lib/libvncclient.so.1
cp /userdata/system/Batocera-CRT-Script/install-vnc_server_batocera/libvncserver.so.1 /usr/lib/libvncserver.so.1
cp /userdata/system/Batocera-CRT-Script/install-vnc_server_batocera/libsasl2.so.2 /usr/lib/libsasl2.so.2
cp /userdata/system/Batocera-CRT-Script/install-vnc_server_batocera/vnc /usr/bin/vnc
cp /userdata/system/Batocera-CRT-Script/install-vnc_server_batocera/x11vnc /usr/bin/x11vnc
cp /userdata/system/Batocera-CRT-Script/install-vnc_server_batocera/vnc-scaled /usr/bin/vnc-scaled

chmod 0755 /lib/libcrypt.so.1
chmod 0644 /usr/lib/libcrypt.so.1
chmod 0644 /usr/lib/libvncclient.so.1
chmod 0644 /usr/lib/libvncserver.so.1
chmod 0644 /usr/lib/libsasl2.so.2
chmod +x /usr/bin/vnc
chmod +x /usr/bin/x11vnc
chmod +x /usr/bin/vnc-scaled

#######################################################################################
# Add Overlays and Overrides for handheld system Tool
#######################################################################################
cp /userdata/system/Batocera-CRT-Script/extra/overlays_overrides.sh /userdata/roms/crt
cp /userdata/system/Batocera-CRT-Script/extra/overlays_overrides.sh.keys /userdata/roms/crt
chmod 755 /userdata/roms/crt/overlays_overrides.sh
chmod 644 /userdata/roms/crt/overlays_overrides.sh.keys
chmod 755 /userdata/system/Batocera-CRT-Script/extra/overlays_overrides_script.sh

#######################################################################################
# Add Media Keys with restart for Xorg and restart Emulation Station
#######################################################################################
cp /userdata/system/Batocera-CRT-Script/extra/media_keys/multimedia_keys.conf /userdata/system/configs/
cp /userdata/system/Batocera-CRT-Script/extra/media_keys/esrestart /usr/bin
cp /userdata/system/Batocera-CRT-Script/extra/media_keys/xrestart /usr/bin
cp /userdata/system/Batocera-CRT-Script/extra/media_keys/emukill /usr/bin
chmod 644 /userdata/system/configs/multimedia_keys.conf
chmod 755 /usr/bin/esrestart
chmod 755 /usr/bin/xrestart
chmod 755 /usr/bin/emukill

#######################################################################################
# Add Kodi to ports folder
#######################################################################################
cp /userdata/system/Batocera-CRT-Script/extra/Kodi/Kodi.sh /userdata/roms/ports
chmod 755 /userdata/roms/ports/Kodi.sh

#######################################################################################
## Save in compilation in batocera image
#######################################################################################
batocera-save-overlay
#######################################################################################
## Put the custom file for the 15KHz modelines for ES and Games 
#######################################################################################

if [ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]; then

	if [  -f "/userdata/system/99-nvidia.conf" ]; then
		cp /userdata/system/99-nvidia.conf /userdata/system/99-nvidia.conf.bak
        fi 

	# MYZAR's WORK and TESTS : THX DUDE !!
	if [ "$CRT_Freq" == "15KHz" ]; then
		sed -e  "s/.*Modeline.*/    Modeline            $MODELINE_CUSTOM/" -e "s/\[card_display\]/$video_modeline/g" /userdata/system/Batocera-CRT-Script/System_configs/Nvidia/99-nvidia.conf-generic_15 > /userdata/system/99-nvidia.conf
	elif [ "$CRT_Freq" == "25KHz" ]; then
		sed -e  "s/.*Modeline.*/    Modeline            $MODELINE_CUSTOM/" -e "s/\[card_display\]/$video_modeline/g" /userdata/system/Batocera-CRT-Script/System_configs/Nvidia/99-nvidia.conf-generic_25 > /userdata/system/99-nvidia.conf
	else
		sed -e "s/\[card_display\]/$video_modeline/g"  /userdata/system/Batocera-CRT-Script/System_configs/Nvidia/99-nvidia.conf-generic_31 > /userdata/system/99-nvidia.conf
	fi

	chmod 644 /userdata/system/99-nvidia.conf

	cp /userdata/system/99-nvidia.conf /userdata/system/99-nvidia.conf.bak
else

	if [ -f "/userdata/system/99-nvidia.conf" ]; then
		cp /userdata/system/99-nvidia.conf /userdata/system/99-nvidia.conf.bak
		rm /userdata/system/99-nvidia.conf
	fi

fi



######################################################################################
# Create a first_script.sh for exiting of Emulationstation
#######################################################################################
##if the folder doesn't exist, it will be create now
if [ ! -d "/userdata/system/scripts" ];then
    mkdir    /userdata/system/scripts
fi 
if [ "$BOOT_RESOLUTION" == "1" ]; then

	sed 	-e "s/\[display_mame_rotation\]/$display_mame_rotate/g" -e "s/\[display_fbneo_rotation\]/$display_fbneo_rotate/g" -e "s/\[display_libretro_rotation\]/$display_libretro_rotate/g" \
		-e "s/\[display_standalone_rotation\]/$display_standalone_rotate/g" -e "s/\[display_ES_rotation\]/$display_rotate/g" \
		-e "s/\[card_display\]/$video_modeline/g" -e "s/\[es_resolution\]/$RES_EDID/g" /userdata/system/Batocera-CRT-Script/System_configs/First_script/first_script.sh-generic-v42 > /userdata/system/scripts/first_script.sh
else
	sed 	-e "s/\[display_mame_rotation\]/$display_mame_rotate/g" -e "s/\[display_fbneo_rotation\]/$display_fbneo_rotate/g" -e "s/\[display_libretro_rotation\]/$display_libretro_rotate/g" \
		-e "s/\[display_standalone_rotation\]/$display_standalone_rotate/g" -e "s/\[display_ES_rotation\]/$display_rotate/g" \
		-e "s/\[card_display\]/$video_modeline/g" -e "s/\[es_resolution\]/$RES_EDID_SCANNING/g" /userdata/system/Batocera-CRT-Script/System_configs/First_script/first_script.sh-generic-v42 > /userdata/system/scripts/first_script.sh
fi
chmod 755 /userdata/system/scripts/first_script.sh
######################################################################################
# Create 1_GunCon2.sh and GunCon2_Calibration.sh
######################################################################################
sed -e "s/\[card_display\]/$video_modeline/g" /userdata/system/Batocera-CRT-Script/System_configs/First_script/1_GunCon2.sh-generic > /userdata/system/scripts/1_GunCon2.sh
chmod 755 /userdata/system/scripts/1_GunCon2.sh
sed -e "s/\[card_display\]/$video_modeline/g" /userdata/system/Batocera-CRT-Script/GunCon2/GunCon2_Calibration.sh-generic > /userdata/roms/crt/GunCon2_Calibration.sh
chmod 755 /userdata/roms/crt/GunCon2_Calibration.sh


#######################################################################################
## Copy of batocera.conf for Libretro cores for use with Switchres
#######################################################################################
# first time using the script save the batocera.conf in batocera.conf.bak
if [ ! -f "/userdata/system/batocera.conf.bak" ];then
	cp /userdata/system/batocera.conf /userdata/system/batocera.conf.bak
fi


# avoid append on each script launch
LINE_NO=$(sed -n '/## ES Settings, See wiki page on how to center EmulationStation/{=;q;}' /userdata/system/batocera.conf.bak)

if [ -z "$LINE_NO" ]; then 
	cp /userdata/system/batocera.conf.bak /userdata/system/batocera.conf 
else 
	truncate -s 0 batocera.conf
	sed -n "1,$(( LINE_NO - 1 )) p; $LINE_NO q" /userdata/system/batocera.conf.bak > /userdata/system/batocera.conf
fi

#######################################################################################
## how create a file /userdatat/system/es.arg.override
#######################################################################################
file="/userdata/system/es.arg.override"

#screensize_x_new=$H_RES_EDID
#screensize_y_new=$V_RES_EDID
screensizeoffset_x_new=00
screensizeoffset_y_new=00
screenoffset_x_new=00
screenoffset_y_new=00

if [ -f "$file" ]; then
	rm $file
fi
touch $file
#echo "screensize_x $screensize_x_new" > "$file"
#echo "screensize_y $screensize_y_new" >> "$file"
echo "screensizeoffset_x $screensizeoffset_x_new" > "$file"
echo "screensizeoffset_y $screensizeoffset_y_new" >> "$file"
echo "screenoffset_x $screenoffset_x_new" >> "$file"
echo "screenoffset_y $screenoffset_y_new" >> "$file"
chmod 644 $file

#######################################################################################
## how to center EmulationStation
#######################################################################################
file_BatoceraConf="/userdata/system/batocera.conf"

if [ "$BOOT_RESOLUTION_ES" == "1" ]; then
	echo $Resolution_es 								>> "$file_BatoceraConf"
fi
echo "## ES Settings, See wiki page on how to center EmulationStation" 			>> "$file_BatoceraConf"

if [ "$ES_rotation" == "NORMAL" ] || [ "$ES_rotation" == "INVERTED" ]; then
	es_customsargs="es.customsargs=--screensize "$H_RES_EDID" "$V_RES_EDID" --screenoffset 00 00"
	es_arg="--screensize "$H_RES_EDID" "$V_RES_EDID" --screenoffset 00 00"
else
	es_customsargs="es.customsargs=--screensize "$V_RES_EDID" "$H_RES_EDID" --screenoffset 00 00"
	es_arg="--screensize "$V_RES_EDID" "$H_RES_EDID" --screenoffset 00 00"
fi
echo $es_customsargs 									>> "$file_BatoceraConf"

#######################################################################################"
## CRT GLOBAL CONFIG FOR RETROARCH
#######################################################################################"
echo "###################################################"                               >> "$file_BatoceraConf"
echo "#	CRT CONFIG RETROARCH"                                                            >> "$file_BatoceraConf"
echo "###################################################"                               >> "$file_BatoceraConf"
echo "###################################################"                               >> "$file_BatoceraConf"
echo "#  RETROARCH MENU DRIVER — RGUI (recommended on CRTs)"                             >> "$file_BatoceraConf"
echo "#    • rgui  — classic, low-overhead, sharp at low resolutions"                    >> "$file_BatoceraConf"
echo "global.retroarch.menu_driver=rgui"                                                 >> "$file_BatoceraConf"
echo "###################################################"                               >> "$file_BatoceraConf"
echo "#  RETROARCH — SHOW ADVANCED SETTINGS (ENABLED)"                                   >> "$file_BatoceraConf"
echo "#"                                                                                 >> "$file_BatoceraConf"
echo "#  What this does:"                                                                >> "$file_BatoceraConf"
echo "#    • Shows hidden expert pages in RetroArch’s menu."                             >> "$file_BatoceraConf"
echo "global.retroarch.menu_show_advanced_settings=true"                                 >> "$file_BatoceraConf"
echo "###################################################"                               >> "$file_BatoceraConf"
echo "#  RETROARCH — MENU WIDGETS (OSD POP-UPS) DISABLED"                                >> "$file_BatoceraConf"
echo "#  Disables toast-style UI elements to keep CRT runs lean and stable."             >> "$file_BatoceraConf"
echo "global.retroarch.menu_enable_widgets=false"                                        >> "$file_BatoceraConf"
echo "###################################################"                               >> "$file_BatoceraConf"
echo "#  RETROARCH — CRT SWITCHRES VIA switchres.ini (MODE 4)"                           >> "$file_BatoceraConf"
echo "#  Delegates modeline decisions to SwitchRes using your switchres.ini."            >> "$file_BatoceraConf"
echo "global.retroarch.crt_switch_resolution = \"4\""                                    >> "$file_BatoceraConf"
echo "###################################################"                               >> "$file_BatoceraConf"
if [ "$dotclock_min" == "25.0" ]; then
	echo "global.retroarch.crt_switch_resolution_super = \"$super_width\""               >> "$file_BatoceraConf"
else
	echo "global.retroarch.crt_switch_resolution_super = \"0\""                          >> "$file_BatoceraConf"
fi
echo "###################################################"                               >> "$file_BatoceraConf"
echo "#  RETROARCH — CRT HI-RES MENU (ENABLED)"                                          >> "$file_BatoceraConf"
echo "#  Use a higher-resolution mode for the RA menu; games stay native."               >> "$file_BatoceraConf"
echo "global.retroarch.crt_switch_hires_menu = \"true\""                                 >> "$file_BatoceraConf"
echo "###################################################"                               >> "$file_BatoceraConf"
echo "#  RETROARCH DESKTOP MENU (Qt) — DISABLED"                                         >> "$file_BatoceraConf"
echo "#  Disable RetroArch's built-in Qt desktop menu interface (WIMP UI)."              >> "$file_BatoceraConf"
echo "#  Even when you don't use the Qt UI, RetroArch still initializes it by default,"  >> "$file_BatoceraConf"
echo "#  which can:"                                                                     >> "$file_BatoceraConf"
echo "#    • add extra CPU overhead and memory usage,"                                   >> "$file_BatoceraConf"
echo "#    • introduce thread contention,"                                               >> "$file_BatoceraConf"
echo "#    • can cause subtle frame or audio timing issues (especially under Xorg)."     >> "$file_BatoceraConf"
echo "#  The setting below disables the Qt desktop UI entirely."                         >> "$file_BatoceraConf"
echo "global.retroarch.desktop_menu_enable = \"false\""                                  >> "$file_BatoceraConf"
echo "###################################################"                               >> "$file_BatoceraConf"
echo "#  DISABLE DEFAULT SHADER, BILINEAR FILTERING & VRR"                               >> "$file_BatoceraConf"
echo "#  Keep pixels sharp and timing stable for native CRT modes."                      >> "$file_BatoceraConf"
echo "global.shaderset=none"                                                             >> "$file_BatoceraConf"
echo "global.smooth=0"                                                                   >> "$file_BatoceraConf"
echo "global.retroarch.vrr_runloop_enable=0"                                             >> "$file_BatoceraConf"
echo "###################################################"                               >> "$file_BatoceraConf"
echo "#  DISABLE / QUIET RETROARCH NOTIFICATIONS"                                        >> "$file_BatoceraConf"
echo "###################################################"                               >> "$file_BatoceraConf"
echo "##  Hide refresh-rate change notification"                                         >> "$file_BatoceraConf"
echo "global.retroarch.notification_show_refresh_rate = \"false\""                       >> "$file_BatoceraConf"
echo "##  Smaller on-screen text for CRTs (default 32 is huge at 240p)"                  >> "$file_BatoceraConf"
echo "global.retroarch.video_font_size = 10" 						                     >> "$file_BatoceraConf"
echo "##  (Optional) Hide the 'Onscreen Display' submenu from RetroArch"                 >> "$file_BatoceraConf"
echo "global.retroarch.settings_show_onscreen_display = \"false\""                       >> "$file_BatoceraConf"
echo "###################################################"                               >> "$file_BatoceraConf"
echo "# ---------- RetroArch — Per-event Notification Toggles ----------"                >> "$file_BatoceraConf"
echo "# These options control specific pop-up toasts."                                   >> "$file_BatoceraConf"
echo "# feedback; change to \"false\" to quiet that specific message."                   >> "$file_BatoceraConf"
echo "## RetroArch per-event notifications — set to \"false\" to hide a given toast"     >> "$file_BatoceraConf"
echo "# Shows a toast when a gamepad autoconfig profile is applied (driver/name)"        >> "$file_BatoceraConf"
echo "global.retroarch.notification_show_autoconfig = \"true\""                          >> "$file_BatoceraConf"
echo "# Shows a toast when cheats are (re)applied to the running content"                >> "$file_BatoceraConf"
echo "global.retroarch.notification_show_cheats_applied = \"true\""                      >> "$file_BatoceraConf"
echo "# Shows a toast when a config override (core/game/dir) is loaded"                  >> "$file_BatoceraConf"
echo "global.retroarch.notification_show_config_override_load = \"true\""                >> "$file_BatoceraConf"
echo "# Shows a toast when fast-forward is toggled (and often the speed)"                >> "$file_BatoceraConf"
echo "global.retroarch.notification_show_fast_forward = \"true\""                        >> "$file_BatoceraConf"
echo "# Shows extra netplay info toasts (join/leave, status, misc events)"               >> "$file_BatoceraConf"
echo "global.retroarch.notification_show_netplay_extra = \"true\""                       >> "$file_BatoceraConf"
echo "# Shows a toast when a ROM patch (IPS/UPS/BPS, etc.) is applied"                   >> "$file_BatoceraConf"
echo "global.retroarch.notification_show_patch_applied = \"true\""                       >> "$file_BatoceraConf"
echo "# Shows a toast when an input remap file is loaded"                                >> "$file_BatoceraConf"
echo "global.retroarch.notification_show_remap_load = \"true\""                          >> "$file_BatoceraConf"
echo "# Shows a toast when a screenshot is captured (usually with save path)"            >> "$file_BatoceraConf"
echo "global.retroarch.notification_show_screenshot = \"true\""                          >> "$file_BatoceraConf"
echo "# Shows a toast when the initial disk is set for multi-disk content"               >> "$file_BatoceraConf"
echo "global.retroarch.notification_show_set_initial_disk = \"true\""                    >> "$file_BatoceraConf"
echo "###################################################"                               >> "$file_BatoceraConf"
echo "##  GUNCON2 SHADER SAVE FIX"                                                       >> "$file_BatoceraConf"
echo "##  Ensures RetroArch actually uses shaders and saves presets as references,"      >> "$file_BatoceraConf"
echo "##  so your GunCon2-related shader presets"                                        >> "$file_BatoceraConf"
echo "##  persist across cores/games and aren’t lost on restart."                        >> "$file_BatoceraConf"
echo "###################################################"                               >> "$file_BatoceraConf"
echo "# Save shader presets as *reference* files instead of flattening/embedding."       >> "$file_BatoceraConf"
echo "# This helps keep per-core/per-game presets (like GunCon2 effects) consistent"     >> "$file_BatoceraConf"
echo "# and prevents accidental overwrites when RA regenerates configs."                 >> "$file_BatoceraConf"
echo "global.retroarch.video_shader_preset_save_reference_enable = \"true\""             >> "$file_BatoceraConf"
echo "# Make sure the shader pipeline is actually enabled globally, so the saved"        >> "$file_BatoceraConf"
echo "# presets load and apply (some setups disable shaders by default)."                >> "$file_BatoceraConf"
echo "global.retroarch.video_shader_enable = \"true\""                                   >> "$file_BatoceraConf"
echo "###################################################"                               >> "$file_BatoceraConf"
echo "##  GLOBAL EMULATOR SETTINGS"                                                      >> "$file_BatoceraConf"
echo "###################################################"                               >> "$file_BatoceraConf"
echo "# Disable Batocera’s bezel artwork system globally (no overlays/frames)"           >> "$file_BatoceraConf"
echo "##  No bezel artwork (use full native game image)"                                 >> "$file_BatoceraConf"
echo "global.bezel=none"                                                                 >> "$file_BatoceraConf"
echo "# Prevent automatic resize of the “tattoo” area when bezels would adjust layout"   >> "$file_BatoceraConf"
echo "# (keeps the gameplay viewport stable and pixel-accurate)"                         >> "$file_BatoceraConf"
echo "##  Don’t auto-resize the bezel/tattoo layout area"                                >> "$file_BatoceraConf"
echo "global.bezel.resize_tattoo=0"                                                      >> "$file_BatoceraConf"
echo "# Hide the bezel “tattoo” watermark/logo (system/game branding)"                   >> "$file_BatoceraConf"
echo "##  Hide bezel watermark/logo (tattoo)"                                            >> "$file_BatoceraConf"
echo "global.bezel.tattoo=0"                                                             >> "$file_BatoceraConf"
echo "# Don’t stretch bezel graphics to fill the screen (avoid distortion)"              >> "$file_BatoceraConf"
echo "##  Don’t stretch bezels to fill screen; preserve proportions"                     >> "$file_BatoceraConf"
echo "global.bezel_stretch=0"                                                            >> "$file_BatoceraConf"
echo "# Disable Batocera HUD overlays (e.g., FPS, temps) during gameplay"                >> "$file_BatoceraConf"
echo "##  Disable Batocera HUD (FPS/temps overlays)"                                     >> "$file_BatoceraConf"
echo "global.hud=none"                                                                   >> "$file_BatoceraConf"
#######################################################################################
##  Rotation of EmulationStation
#######################################################################################

term_rotation="display.rotate="
term_es_rotation=$term_rotation$((es_rotation_choice-1))
echo "###################################################"                               >> "$file_BatoceraConf"
echo "#  EMULATIONSTATION UI ROTATION (MENU & THEME ONLY)"                               >> "$file_BatoceraConf"
echo "#  Sets the orientation of EmulationStation’s interface."                          >> "$file_BatoceraConf"
echo "#  This does NOT rotate games; emulators are handled separately by the script."    >> "$file_BatoceraConf"
echo "#  ES ROTATION  MODE" 								                             >> "$file_BatoceraConf"
echo $term_es_rotation									                                 >> "$file_BatoceraConf"

#######################################################################################
## Mame initialisation Batocera not for RetroLX at this time
#######################################################################################

cd /usr/bin/mame
./mame -cc
case $Version_of_batocera in
 	v39)
		if [ ! -d "/userdata/system/configs/mame" ];then
			mkdir /userdata/system/configs/mame
			mkdir /userdata/system/configs/mame/ini
		elif [ ! -d "/userdata/system/configs/mame/ini" ];then
			mkdir /userdata/system/configs/mame/ini
		fi
		mv /usr/bin/mame/*.ini /userdata/system/configs/mame/
		sed -e "s/\[monitor-name\]/$monitor_name_MAME/g" -e "s/\[super_width_mame\]/$super_width_mame/g" -e "s/\[dotclock_min_mame\]/$dotclock_min_mame/g" \
			/userdata/system/Batocera-CRT-Script//Mame_configs/mame.ini-switchres-generic-v36 > /userdata/system/configs/mame/mame.ini
		chmod 644 /userdata/system/configs/mame/mame.ini
		cp /userdata/system/Batocera-CRT-Script/Mame_configs/ui.ini-switchres /userdata/system/configs/mame/ui.ini
		chmod 644 /userdata/system/configs/mame/ui.ini

 		cp /userdata/system/Batocera-CRT-Script/GunCon2/gunlight/plugin.ini /userdata/system/configs/mame/plugin.ini
		chmod 644 /userdata/system/configs/mame/plugin.ini
	;;
 	v40)
		if [ ! -d "/userdata/system/configs/mame" ];then
			mkdir /userdata/system/configs/mame
			mkdir /userdata/system/configs/mame/ini
		elif [ ! -d "/userdata/system/configs/mame/ini" ];then
			mkdir /userdata/system/configs/mame/ini
		fi
		mv /usr/bin/mame/*.ini /userdata/system/configs/mame/
		sed -e "s/\[monitor-name\]/$monitor_name_MAME/g" -e "s/\[super_width_mame\]/$super_width_mame/g" -e "s/\[dotclock_min_mame\]/$dotclock_min_mame/g" \
			/userdata/system/Batocera-CRT-Script//Mame_configs/mame.ini-switchres-generic-v36 > /userdata/system/configs/mame/mame.ini
		chmod 644 /userdata/system/configs/mame/mame.ini
		cp /userdata/system/Batocera-CRT-Script/Mame_configs/ui.ini-switchres /userdata/system/configs/mame/ui.ini
		chmod 644 /userdata/system/configs/mame/ui.ini

 		cp /userdata/system/Batocera-CRT-Script/GunCon2/gunlight/plugin.ini /userdata/system/configs/mame/plugin.ini
		chmod 644 /userdata/system/configs/mame/plugin.ini
	;;
	v41)
		if [ ! -d "/userdata/system/configs/mame" ];then
			mkdir /userdata/system/configs/mame
			mkdir /userdata/system/configs/mame/ini
		elif [ ! -d "/userdata/system/configs/mame/ini" ];then
			mkdir /userdata/system/configs/mame/ini
		fi
		mv /usr/bin/mame/*.ini /userdata/system/configs/mame/
		sed -e "s/\[monitor-name\]/$monitor_name_MAME/g" -e "s/\[super_width_mame\]/$super_width_mame/g" -e "s/\[dotclock_min_mame\]/$dotclock_min_mame/g" \
			/userdata/system/Batocera-CRT-Script//Mame_configs/mame.ini-switchres-generic-v36 > /userdata/system/configs/mame/mame.ini
		chmod 644 /userdata/system/configs/mame/mame.ini
		cp /userdata/system/Batocera-CRT-Script/Mame_configs/ui.ini-switchres /userdata/system/configs/mame/ui.ini
		chmod 644 /userdata/system/configs/mame/ui.ini

 		cp /userdata/system/Batocera-CRT-Script/GunCon2/gunlight/plugin.ini /userdata/system/configs/mame/plugin.ini
		chmod 644 /userdata/system/configs/mame/plugin.ini
	;;
	v42)
		if [ ! -d "/userdata/system/configs/mame" ];then
			mkdir /userdata/system/configs/mame
			mkdir /userdata/system/configs/mame/ini
		elif [ ! -d "/userdata/system/configs/mame/ini" ];then
			mkdir /userdata/system/configs/mame/ini
		fi
		mv /usr/bin/mame/*.ini /userdata/system/configs/mame/
		sed -e "s/\[monitor-name\]/$monitor_name_MAME/g" -e "s/\[super_width_mame\]/$super_width_mame/g" -e "s/\[dotclock_min_mame\]/$dotclock_min_mame/g" \
			/userdata/system/Batocera-CRT-Script//Mame_configs/mame.ini-switchres-generic-v36 > /userdata/system/configs/mame/mame.ini
		chmod 644 /userdata/system/configs/mame/mame.ini
		cp /userdata/system/Batocera-CRT-Script/Mame_configs/ui.ini-switchres /userdata/system/configs/mame/ui.ini
		chmod 644 /userdata/system/configs/mame/ui.ini

 		cp /userdata/system/Batocera-CRT-Script/GunCon2/gunlight/plugin.ini /userdata/system/configs/mame/plugin.ini
		chmod 644 /userdata/system/configs/mame/plugin.ini
	;;


	*)
		echo "Problem of version"
	;;
esac

cp /userdata/system/configs/mame/mame.ini       /userdata/system/configs/mame/mame.ini.bak 

#######################################################################################
## UPGRADE Mame  Batocera  create an folder for new binary of MAME (GroovyMame)
####################################################################################### 
if [ ! -d "/userdata/system//mame" ];then
	mkdir /userdata/system/mame
fi

####################################################################################### 
echo "###################################################"				>> "$file_BatoceraConf"
echo "##  CRT SYSTEM SETTINGS" 								            >> "$file_BatoceraConf"
echo "###################################################" 				>> "$file_BatoceraConf"
echo "CRT.emulator=sh" 									                >> "$file_BatoceraConf"
echo "CRT.core=sh" 									                    >> "$file_BatoceraConf"
echo "###################################################" 				>> "$file_BatoceraConf"
echo "##  GROOVYMAME EMULATOR SETTINGS" 						        >> "$file_BatoceraConf"
echo "###################################################" 				>> "$file_BatoceraConf"
echo "mame.bezel=none" 									                >> "$file_BatoceraConf"
echo "mame.bezel_stretch=0" 								            >> "$file_BatoceraConf"
echo "mame.core=mame" 									                >> "$file_BatoceraConf"
echo "mame.emulator=mame" 								                >> "$file_BatoceraConf"
echo "mame.bezel.tattoo=0" 								                >> "$file_BatoceraConf"
echo "mame.bgfxshaders=None" 								            >> "$file_BatoceraConf"
echo "mame.hud=none" 									                >> "$file_BatoceraConf"
echo "mame.switchres=1" 								                >> "$file_BatoceraConf"
echo "###################################################" 				>> "$file_BatoceraConf"
echo "##  NEOGEO SYSTEM SETTINGS" 							            >> "$file_BatoceraConf"
echo "###################################################" 				>> "$file_BatoceraConf"
echo "neogeo.bezel=none" 								                >> "$file_BatoceraConf"
echo "neogeo.bezel_stretch=0" 								            >> "$file_BatoceraConf"
echo "neogeo.core=mame" 								                >> "$file_BatoceraConf"
echo "neogeo.emulator=mame" 							                >> "$file_BatoceraConf"
echo "neogeo.bezel.tattoo=0" 								            >> "$file_BatoceraConf"
echo "neogeo.bgfxshaders=None" 								            >> "$file_BatoceraConf"
echo "neogeo.hud=none"									                >> "$file_BatoceraConf"
echo "neogeo.switchres=1" 								                >> "$file_BatoceraConf"
echo "###################################################" 				>> "$file_BatoceraConf"
echo "##  MAME EMULATOR SETTINGS" 							            >> "$file_BatoceraConf"
echo "##  APPLE2 / CAMPUTER LYNX / ACORN BBC/ELECTRON/ARCHIMEDE" 	    >> "$file_BatoceraConf"
echo "###################################################" 				>> "$file_BatoceraConf"
echo "apple2.core=mame" 								                >> "$file_BatoceraConf"
echo "apple2.emulator=mame" 							                >> "$file_BatoceraConf"
echo "apple2.switchres=1" 								                >> "$file_BatoceraConf"
echo "bbc.core=mame" 									                >> "$file_BatoceraConf"
echo "bbc.emulator=mame" 								                >> "$file_BatoceraConf"
echo "bbc.switchres=1" 									                >> "$file_BatoceraConf"
echo "electron.core=mame" 								                >> "$file_BatoceraConf"
echo "electron.emulator=mame" 								            >> "$file_BatoceraConf"
echo "electron.switchres=1" 								            >> "$file_BatoceraConf"
echo "archimedes.core=mame" 								            >> "$file_BatoceraConf"
echo "archimedes.emulator=mame" 							            >> "$file_BatoceraConf"
echo "archimedes.switchres=1" 								            >> "$file_BatoceraConf"
echo "camplynx.core=mame"								                >> "$file_BatoceraConf"
echo "camplynx.emulator=mame"								            >> "$file_BatoceraConf"
echo "camplynx.switchres=1" 								            >> "$file_BatoceraConf"
echo "###################################################" 				>> "$file_BatoceraConf"
echo "##  STANDALONE EMULATOR SETTINGS" 						        >> "$file_BatoceraConf"
echo "###################################################" 				>> "$file_BatoceraConf"
echo "amiga500.core=A500" 								                >> "$file_BatoceraConf"
echo "amiga500.cpu_compatibility=exact" 				                >> "$file_BatoceraConf"
echo "amiga500.emulator=fsuae" 							                >> "$file_BatoceraConf"
echo "amiga500.video_allow_rotate=true" 				                >> "$file_BatoceraConf"
echo "amigacd32.core=CD32" 								                >> "$file_BatoceraConf"
echo "amigacd32.emulator=fsuae" 						                >> "$file_BatoceraConf"
echo "atarist.core=hatari" 								                >> "$file_BatoceraConf"
echo "atarist.emulator=hatari" 							                >> "$file_BatoceraConf"
echo "dos.core=dosbox" 									                >> "$file_BatoceraConf"
echo "dos.emulator=dosbox" 								                >> "$file_BatoceraConf"
echo "msx1.core=openmsx" 								                >> "$file_BatoceraConf"
echo "msx1.emulator=openmsx" 							                >> "$file_BatoceraConf"
echo "msx2.core=openmsx" 								                >> "$file_BatoceraConf"
echo "msx2.emulator=openmsx"							                >> "$file_BatoceraConf"
echo "msx2+.core=openmsx" 								                >> "$file_BatoceraConf"
echo "flash.core=lightspark" 							                >> "$file_BatoceraConf"
echo "flash.emulator=lightspark" 						                >> "$file_BatoceraConf"
echo "msx2+.emulator=openmsx" 							                >> "$file_BatoceraConf"
echo "###################################################" 				>> "$file_BatoceraConf"
echo "##  GROOVYMAME TATE SETTINGS" 							        >> "$file_BatoceraConf"
echo "###################################################" 				>> "$file_BatoceraConf"
 
if [ -d "/userdata/system/configs/mame/ini" ];then
	if [ -f "/userdata/system/configs/mame/ini/horizont.ini" ];then
		rm /userdata/system/configs/mame/ini/horizont.ini
	fi
if [ -f "/userdata/system/configs/mame/ini/vertical.ini" ];then
		rm /userdata/system/configs/mame/ini/vertical.ini
	fi
fi

if [ $es_rotation_choice -eq 1 ]; then
	echo "mame.rotation=none" 							>> "$file_BatoceraConf"
	case $Rotating_screen in 
		None)
			sed -e "s/\[super_width_vertical\]/$super_width_vertical/g" -e "s/\[interlace_vertical\]/$interlace_vertical/g" -e "s/\[dotclock_min_vertical\]/$dotclock_min_vertical/g" \
				/userdata/system/Batocera-CRT-Script/Mame_configs/Mame_TATE/vertical_normal.ini > /userdata/system/configs/mame/ini/vertical.ini
		;;
		Clockwise)
			sed -e "s/\[super_width_vertical\]/$super_width_vertical/g" -e "s/\[interlace_vertical\]/$interlace_vertical/g" -e "s/\[dotclock_min_vertical\]/$dotclock_min_vertical/g" \
				  /userdata/system/Batocera-CRT-Script/Mame_configs/Mame_TATE/vertical_clockwise.ini > /userdata/system/configs/mame/ini/vertical.ini
		;;
		Counter-Clockwise)
			sed -e "s/\[super_width_vertical\]/$super_width_vertical/g" -e "s/\[interlace_vertical\]/$interlace_vertical/g" -e "s/\[dotclock_min_vertical\]/$dotclock_min_vertical/g" \
				 /userdata/system/Batocera-CRT-Script/Mame_configs/Mame_TATE/vertical_counter-clockwise.ini > /userdata/system/configs/mame/ini/vertical.ini
		;;
		*)
			echo "Problems of rotation_choice"
		;;
	esac
	echo "fbneo.video_allow_rotate=off"						>> "$file_BatoceraConf"
fi

if [ $es_rotation_choice -eq 2 ]; then
	echo "mame.rotation=autoror"							>> "$file_BatoceraConf"
	case $Rotating_screen in 
		None)	
			sed -e "s/\[super_width_horizont\]/$super_width_horizont/g" -e "s/\[interlace_horizont\]/$interlace_horizont/g" -e "s/\[dotclock_min_horizont\]/$dotclock_min_horizont/g" \
					/userdata/system/Batocera-CRT-Script/Mame_configs/Mame_TATE/horizont_inverted.ini > /userdata/system/configs/mame/ini/horizont.ini
		;;
		Clockwise)
			sed -e "s/\[super_width_horizont\]/$super_width_horizont/g" -e "s/\[interlace_horizont\]/$interlace_horizont/g" -e "s/\[dotclock_min_horizont\]/$dotclock_min_horizont/g" \
					/userdata/system/Batocera-CRT-Script/Mame_configs/Mame_TATE/horizont_counter-clockwise.ini > /userdata/system/configs/mame/ini/horizont.ini
		;;
		Counter-Clockwise)
			sed -e "s/\[super_width_horizont\]/$super_width_horizont/g" -e "s/\[interlace_horizont\]/$interlace_horizont/g" -e "s/\[dotclock_min_horizont\]/$dotclock_min_horizont/g" \
					/userdata/system/Batocera-CRT-Script/Mame_configs/Mame_TATE/horizont_clockwise.ini > /userdata/system/configs/mame/ini/horizont.ini
		;;
		*)
			echo "Problems of rotation_choice"
		;;
	esac
	echo "fbneo.video_allow_rotate=off"						>> "$file_BatoceraConf"
fi

if [ $es_rotation_choice -eq 3 ]; then
	echo "mame.rotation=none" 							>> "$file_BatoceraConf"
	case $Rotating_screen in 
		None)
			sed -e "s/\[super_width_vertical\]/$super_width_vertical/g" -e "s/\[interlace_vertical\]/$interlace_vertical/g" -e "s/\[dotclock_min_vertical\]/$dotclock_min_vertical/g" \
				/userdata/system/Batocera-CRT-Script/Mame_configs/Mame_TATE/vertical_inverted.ini > /userdata/system/configs/mame/ini/vertical.ini
		;;
		Clockwise)
			sed -e "s/\[super_width_vertical\]/$super_width_vertical/g" -e "s/\[interlace_vertical\]/$interlace_vertical/g" -e "s/\[dotclock_min_vertical\]/$dotclock_min_vertical/g" \
				/userdata/system/Batocera-CRT-Script/Mame_configs/Mame_TATE/vertical_clockwise.ini > /userdata/system/configs/mame/ini/vertical.ini
		;;
		Counter-Clockwise)
			sed -e "s/\[super_width_vertical\]/$super_width_vertical/g" -e "s/\[interlace_vertical\]/$interlace_vertical/g" -e "s/\[dotclock_min_vertical\]/$dotclock_min_vertical/g" \
				/userdata/system/Batocera-CRT-Script/Mame_configs/Mame_TATE/vertical_counter-clockwise.ini > /userdata/system/configs/mame/ini/vertical.ini      
		;;
		*)
			echo "Problems of rotation_choice"
		;;
	esac
	echo "fbneo.video_allow_rotate=off"						 >> "$file_BatoceraConf"
fi

if [ $es_rotation_choice -eq 4 ]; then
	echo "mame.rotation=autorol"							>> "$file_BatoceraConf"
	case $Rotating_screen in 
		None)
			sed -e "s/\[super_width_horizont\]/$super_width_horizont/g" -e "s/\[interlace_horizont\]/$interlace_horizont/g" -e "s/\[dotclock_min_horizont\]/$dotclock_min_horizont/g" \
				/userdata/system/Batocera-CRT-Script/Mame_configs/Mame_TATE/horizont_normal.ini > /userdata/system/configs/mame/ini/horizont.ini
		;;
		Clockwise)
			sed -e "s/\[super_width_horizont\]/$super_width_horizont/g" -e "s/\[interlace_horizont\]/$interlace_horizont/g" -e "s/\[dotclock_min_horizont\]/$dotclock_min_horizont/g" \
				/userdata/system/Batocera-CRT-Script/Mame_configs/Mame_TATE/horizont_clockwise.ini > /userdata/system/configs/mame/ini/horizont.ini
		;;
		Counter-Clockwise)
			sed -e "s/\[super_width_horizont\]/$super_width_horizont/g" -e "s/\[interlace_horizont\]/$interlace_horizont/g" -e "s/\[dotclock_min_horizont\]/$dotclock_min_horizont/g" \
				/userdata/system/Batocera-CRT-Script/Mame_configs/Mame_TATE/horizont_counter-clockwise.ini > /userdata/system/configs/mame/ini/horizont.ini
			;;
			*)
				echo "Problems of rotation_choice"
			;;
		esac
	echo "fbneo.video_allow_rotate=off" 						>> "$file_BatoceraConf"
fi
chmod 755 "$file_BatoceraConf"
# -----------------------------------------------------------------------------
# Finalize: install /boot/boot-custom.sh when not on NVIDIA proprietary
# -----------------------------------------------------------------------------
maybe_install_boot_custom_sh

# -----------------------------------------------------------------------------
# Show final first-boot instructions and reboot
# (Requires: box_hash, box_center, and color vars defined earlier)
# -----------------------------------------------------------------------------
if declare -f show_first_boot_instructions_and_reboot >/dev/null 2>&1; then
  show_first_boot_instructions_and_reboot
else
  # Fallback (shouldn't happen): print a minimal message, then reboot
  echo -e "${GREEN}${BOLD}Setup complete. Press ENTER to reboot...${NOCOLOR}"
  read -r
  if command -v systemctl >/dev/null 2>&1; then
    systemctl reboot
  else
    sync
    reboot
  fi
fi

exit 0


