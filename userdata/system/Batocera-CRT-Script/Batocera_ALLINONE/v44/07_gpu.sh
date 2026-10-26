
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
		while [[ ! ${choice_Drivers_Nvidia} =~ ^[1-$((var+1))]$ ]] ; do
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

			declare -a Name_Nvidia_drivers_version=( "true" "legacy580" "legacy470" )
			for var in "${!Name_Nvidia_drivers_version[@]}"; do
				if [ "${Name_Nvidia_drivers_version[$var]}" = "true" ]; then
					echo "			$((var+1)) : true (Default - Recommended)"
				else
					echo "			$((var+1)) : ${Name_Nvidia_drivers_version[$var]}"
				fi
			done

			box_hash
			box_center "Make your choice"
			box_hash

			center_plain_log "Select option 1 to $((var+1)):"
			read choice_Name_Drivers_Nvidia
			while [[ ! ${choice_Name_Drivers_Nvidia} =~ ^[1-$((var+1))]$ ]] ; do
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
