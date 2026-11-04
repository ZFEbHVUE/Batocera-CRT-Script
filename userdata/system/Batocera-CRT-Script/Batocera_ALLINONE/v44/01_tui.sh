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
