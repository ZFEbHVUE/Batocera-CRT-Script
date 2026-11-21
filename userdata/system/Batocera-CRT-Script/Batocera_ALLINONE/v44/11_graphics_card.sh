# Batocera-CRT-Script v44 - step 11: graphics card
# Graphics card: list, choice and type -> TYPE_OF_CARD. NVIDIA: driver and version; AMD: R9 380
# amdgpu.dc=0 fix, then the per-card display-engine prescan (/tmp/crt-detect/cardN.env).
echo; printf "%s\n" "$border"; empty_line; center "Discrete Graphics Card (dGPU) / Accelerated Processing Unit (APU)"
empty_line; printf "%s\n" "$border"; j=0
for p in /sys/class/drm/card? ; do
	id=$(basename "$(readlink -f "$p/device")")
	temp=$(lspci -mms "$id" | cut -d '"' -f4,6)
	name_card[$j]="$temp"
	j=$((j + 1))
done
box_empty
for var in "${!name_card[@]}"; do echo "	$((var+1)) : ${name_card[$var]}" | tee -a "$CRT_LOG"; done
if [[ "$var" -gt 0 ]] ; then
  hbox "Make your choice for graphic card"; ask card_choice $((var+1)) e; selected_card=${name_card[$card_choice-1]}
else selected_card=${temp}; fi
Drivers_Nvidia_CHOICE="NONE"
case $selected_card in
	*[Nn][Vv][Ii][Dd][Ii][Aa]*)
		TYPE_OF_CARD="NVIDIA"; echo "NVIDIA" > "$TCD"; hbox "YOUR VIDEO CARD IS ${GREEN}NVIDIA${NOCOLOR}"
		hbox "Do you want Nvidia_Drivers or NOUVEAU"
		declare -a Nvidia_drivers_type=( "Nvidia_Drivers" "NOUVEAU" )
		for var in "${!Nvidia_drivers_type[@]}"; do echo "			$((var+1)) : ${Nvidia_drivers_type[$var]}"; done
		hbox "Make your choice"
		ask choice_Drivers_Nvidia $((var+1))
		Drivers_Nvidia_CHOICE=${Nvidia_drivers_type[$choice_Drivers_Nvidia-1]}
		box_center "your choice is :  ${GREEN}$Drivers_Nvidia_CHOICE${NOCOLOR}"; echo "$Drivers_Nvidia_CHOICE" >> "$TCD"
		if [ "$Drivers_Nvidia_CHOICE" == "Nvidia_Drivers" ]; then
			hbox "Nvidia drivers version selector"
			declare -a Name_Nvidia_drivers_version=( "true" "legacy580" "legacy470" )
			for var in "${!Name_Nvidia_drivers_version[@]}"; do
				if [ "${Name_Nvidia_drivers_version[$var]}" = "true" ]; then
					echo "			$((var+1)) : true (Default - Recommended)"
				else echo "			$((var+1)) : ${Name_Nvidia_drivers_version[$var]}"; fi
			done
			hbox "Make your choice"
			ask choice_Name_Drivers_Nvidia $((var+1))
			Drivers_Name_Nvidia_CHOICE=${Name_Nvidia_drivers_version[$choice_Name_Drivers_Nvidia-1]}
			box_center "your choice is :  ${GREEN}$Drivers_Name_Nvidia_CHOICE${NOCOLOR}"
		fi ;;
	*[Ii][Nn][Tt][Ee][Ll]*)
		TYPE_OF_CARD="INTEL"; hbox "YOUR VIDEO CARD IS ${GREEN}INTEL${NOCOLOR}"
		echo "INTEL" > "$TCD" ;;
	*[Aa][Mm][Dd]* | *[Aa][Tt][Ii]*)
		TYPE_OF_CARD="AMD/ATI"
		if [ -f "$TCD" ]; then printf 'AMD/ATI\nAMD/ATI\n' > "$TCD"; else echo "AMD/ATI" > "$TCD"; fi   # a re-run writes AMD/ATI twice (as before)
		hbox "YOUR VIDEO CARD IS ${GREEN}AMD/ATI${NOCOLOR}"
if echo "$selected_card" | grep -qi 'r9' && echo "$selected_card" | grep -q '380'; then
  R9_380="YES"; hbox "You have an ${GREEN}ATI R9 380/380x${NOCOLOR}"
  SYS_CAND="/boot/EFI/syslinux.cfg /boot/EFI/BOOT/syslinux.cfg /boot/boot/syslinux.cfg /boot/boot/syslinux/syslinux.cfg"
  need_fix=0; found_any=0
  for f in $SYS_CAND; do
    [ -f "$f" ] || continue; found_any=1
    if ! grep -q 'amdgpu\.dc=0' "$f"; then
      need_fix=1; break
    fi
  done
  if [ "$found_any" -eq 1 ] && [ "$need_fix" -eq 0 ]; then
    hbox "${GREEN}This discrete dGPU/APU is ready for 15KHz${NOCOLOR}"
	prompt_centered_tty "PRESS ${BLUE}ENTER${NOCOLOR} TO CONTINUE TO SCANNING OUTPUTS. THIS MAY TAKE UP TO 20-30 SECONDS. PLEASE WAIT)"
  else
    box_hash
    if [ "$found_any" -eq 0 ]; then
      box_center "${RED}No syslinux.cfg files found to update${NOCOLOR}"
    else
      box_center "${RED}This discrete GPU (dGPU) is not ready for 15KHz${NOCOLOR}"
      box_center "Need to add amdgpu.dc=0 to syslinux.cfg"
    fi
    box_hash; prompt_centered_tty "PRESS ${BLUE}ENTER${NOCOLOR} TO UPDATE syslinux.cfg"
    mount -o remount,rw /boot 2>/dev/null || true
    for f in $SYS_CAND; do
      [ -f "$f" ] || continue; cp -f "$f" "${f}.bak" 2>/dev/null || true
      if [ ! -f "${f}.initial" ]; then cp -f "$f" "${f}.initial" 2>/dev/null || true; fi
      if grep -q 'amdgpu\.dc=0' "$f"; then
        chmod 755 "$f" 2>/dev/null || true; continue
      fi
      tmpf="${f}.patched"
      if grep -q 'mitigations=off' "$f"; then
        sed 's/mitigations=off/& amdgpu.dc=0 /' "$f" > "$tmpf"
      else sed 's/^\([[:space:]]*APPEND[[:space:]].*\)$/\1 amdgpu.dc=0 /' "$f" > "$tmpf"; fi
      mv -f "$tmpf" "$f"; chmod 755 "$f" 2>/dev/null || true; echo "Updated $f (added amdgpu.dc=0)" | tee -a "$CRT_LOG"
    done
    hbox "ENTER to reboot and finalize 15KHz setup for this card"
    prompt_centered_tty "PRESS ${BLUE}ENTER${NOCOLOR} TO REBOOT"; reboot; exit
  fi
  source_file="${CRTD}/System_configs/R9/v42/es_settings.cfg"
  destination_file="/userdata/system/configs/emulationstation/es_settings.cfg"
  if [ ! -f "$destination_file" ]; then
    cp "$source_file" "$destination_file"; chmod 0644 "$destination_file"
  else
    if ! grep -q '<string name="GameTransitionStyle" value="instant" />' "$destination_file"; then
      cp "$source_file" "$destination_file"; chmod 0644 "$destination_file"
    fi
  fi
else
  R9_380="NO"; hbox "${GREEN}This card is ready for 15KHz${NOCOLOR}"
  prompt_centered_tty "PRESS ${BLUE}ENTER${NOCOLOR} TO CONTINUE"
fi
PCI_LIST="${CRTD}/Cards_detection/list_detection_amd_apu.txt"; OUTDIR="/tmp/crt-detect"; mkdir -p "$OUTDIR"
rm -f "$OUTDIR"/card*.env 2>/dev/null || true
mount | grep -q " on /sys/kernel/debug type debugfs " || mount -t debugfs debugfs /sys/kernel/debug 2>/dev/null || true
if mount | grep -q " on /sys/kernel/debug type debugfs "; then
  echo "debugfs mounted." >> "$CRT_LOG"
else echo "debugfs NOT mounted (DISPLAY_ENGINE may be NONE)." >> "$CRT_LOG"; fi
shopt -s nullglob
parse_display_engine_from_text() {
  local line; PARSED_ENGINE=""; PARSED_VERSION=""
  while IFS= read -r line; do
    line="$(printf '%s' "$line" | tr '_' ' ' )"
    if printf '%s\n' "$line" | grep -qiE '(dcn|display[[:space:]_]*core)'; then
      ver="$(printf '%s\n' "$line" | awk 'BEGIN{IGNORECASE=1}
        {
          n=split($0,a,/[^0-9]+/); c=0; out="";
          for(i=1;i<=n && c<3;i++){
            if(a[i]~/^[0-9]+$/){ c++; out=(out==""?a[i]:out"."a[i]); }
          }
          if(c>0){ print out; exit }
        }')"
      PARSED_ENGINE="DCN"; PARSED_VERSION="$ver"; [ -n "$PARSED_VERSION" ] || PARSED_VERSION=""; return 0
    fi
  done
  if [ -z "$OUT_ENGINE" ]; then engine_from_lspci "${AMD_PCI_ADDR:-${PCI_ADDR:-}}"; fi
return 1
}
read_engine_anywhere() {
  local IDX="$1"; OUT_ENGINE=""; OUT_VERSION=""; local f
  echo "Engine detect: probing debugfs files for card${IDX}" >> "$CRT_LOG"
  for f in \
    "/sys/kernel/debug/dri/${IDX}/amdgpu_ip_info" \
    "/sys/kernel/debug/dri/${IDX}/amdgpu_ip_discovery" \
    "/sys/kernel/debug/dri/${IDX}/amdgpu_dm_info" \
    "/sys/kernel/debug/dri/${IDX}/amdgpu_firmware_info" \
    "/sys/kernel/debug/dri/${IDX}/amdgpu_vbios_info" \
    "/sys/kernel/debug/dri/${IDX}/amdgpu_pm_info"
  do
    if [ -r "$f" ]; then
      echo "  + exists: $f ($(stat -c %s "$f" 2>/dev/null || echo ? ) bytes)" >> "$CRT_LOG"
      head -n 20 "$f" 2>/dev/null | sed "s/^/    | /" >> "$CRT_LOG"
      if parse_display_engine_from_text < "$f"; then
		echo "  -> parsed engine from: $f => engine=${PARSED_ENGINE:-unknown} version=${PARSED_VERSION:-unknown}" >> "$CRT_LOG"
        OUT_ENGINE="$PARSED_ENGINE"; OUT_VERSION="$PARSED_VERSION"; [ -n "$OUT_ENGINE" ] && return 0
      fi
    fi
  done
  if dmesg 2>/dev/null | grep -qiE '(dcn|dce|display core|display controller)'; then
    echo "Engine detect: trying dmesg parse (card${IDX})" >> "$CRT_LOG"
    if dmesg 2>/dev/null | parse_display_engine_from_text; then
	  echo "  -> parsed engine from: dmesg => engine=${PARSED_ENGINE:-unknown} version=${PARSED_VERSION:-unknown}" >> "$CRT_LOG"
      OUT_ENGINE="$PARSED_ENGINE"; OUT_VERSION="$PARSED_VERSION"; [ -n "$OUT_ENGINE" ] && return 0
    fi
  fi
  if [ -z "$OUT_ENGINE" ]; then
    local _pci=""
    if [ -e "/sys/class/drm/card${IDX}/device" ]; then _pci="$(basename "$(readlink -f "/sys/class/drm/card${IDX}/device")")"; fi
    engine_from_lspci "$_pci"
  fi
  if [ -n "${OUT_ENGINE:-}" ]; then return 0; fi
return 1
}
infer_engine_from_chip() {
  local chip="$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')"
  case "$chip" in
    CHIP_NAVI*|CHIP_SIENNA_CICHLID|CHIP_NAVY_FLOUNDER|CHIP_DIMGREY_CAVEFISH|CHIP_BEIGE_GOBY|\
CHIP_ARCTURUS|CHIP_ALDEBARAN|\
CHIP_RAVEN|CHIP_RAVEN2|CHIP_RENOIR|CHIP_GREEN_SARDINE|CHIP_CEZANNE|CHIP_YELLOW_CARP|\
CHIP_VANGOGH|CHIP_MENDOCINO|CHIP_PHOENIX|CHIP_PHOENIX2|CHIP_RAPHAEL|CHIP_STRIX*|CHIP_HAWK*) echo DCN; return 0;;
    CHIP_VEGA*|CHIP_VEGAM|CHIP_FIJI|\
CHIP_TONGA|CHIP_POLARIS*|CHIP_HAWAII|CHIP_BONAIRE|\
CHIP_TAHITI|CHIP_PITCAIRN|CHIP_VERDE|CHIP_OLAND|CHIP_TOPAZ|\
CHIP_KABINI|CHIP_KAVERI|CHIP_CARRIZO|CHIP_STONEY|CHIP_MULLINS) echo DCE; return 0;;
    *) return 1;;
  esac
}
infer_from_pci_list() {
  local ven="$1" dev="$2" list="$3"; [ -r "$list" ] || return 1; local line
  line="$(grep -iE "[^0-9A-Fa-f\{]*\{0x${ven},[[:space:]]*0x${dev}," "$list" | head -n1)"; [ -n "$line" ] || return 1
  if printf '%s' "$line" | grep -q 'AMD_IS_APU'; then
    echo "PCI list: AMD_IS_APU flag present for ${ven}:${dev}" >> "$CRT_LOG"; AMD_IS_APU=1
    APU_REASON="legacy list (PCI table)"
  fi
  local chip; chip="$(printf '%s' "$line" | sed -nE 's/.*(CHIP_[A-Za-z0-9_]+).*/\1/p' | head -n1)"
  if [ -n "$chip" ]; then
    local eng; eng="$(infer_engine_from_chip "$chip" || true)"
    if [ -n "$eng" ] && [ "${DISPLAY_ENGINE:-NONE}" = "NONE" ]; then
      DISPLAY_ENGINE="$eng"; DISPLAY_VERSION=""
      echo "PCI list: inferred engine ${eng} from ${chip} for ${ven}:${dev}" >> "$CRT_LOG"; return 0
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
is_amd_card() { [[ -e "$1/device/vendor" ]] && [[ "$(tr '[:upper:]' '[:lower:]' < "$1/device/vendor")" == "0x1002" ]]; }
process_card_prescan() {
  local CARD="$1"; local IDX="${CARD##*/card}"; local DEV="$CARD/device"
  local PCI_ADDR; PCI_ADDR="$(basename "$(readlink -f "$DEV")")"
  local VEN DEVHEX; VEN="$(<"$DEV/vendor")"; DEVHEX="$(<"$DEV/device")"; VEN="${VEN#0x}"; DEVHEX="${DEVHEX#0x}"
  local LSPCI_LINE="AMD GPU at ${PCI_ADDR}"
  if command -v lspci >/dev/null 2>&1; then LSPCI_LINE=$(lspci -s "${PCI_ADDR#0000:}" -nn 2>/dev/null | sed 's/^[^:]*: //') || true; fi
  local IPINFO="/sys/kernel/debug/dri/${IDX}/amdgpu_ip_info"; local AMD_IS_APU=0 APU_REASON=""
  local DISPLAY_ENGINE="NONE" DISPLAY_VERSION=""
  if [[ -r "$PCI_LIST" ]] && grep -iq "{0x$VEN, 0x$DEVHEX, .*AMD_IS_APU}" "$PCI_LIST"; then AMD_IS_APU=1; APU_REASON="legacy list (PCI table)"; fi
  if read_engine_anywhere "$IDX"; then
    echo "Engine detect: read_engine_anywhere OK for card${IDX}: ${OUT_ENGINE} ${OUT_VERSION}" >> "$CRT_LOG"
    DISPLAY_ENGINE="$OUT_ENGINE"; DISPLAY_VERSION="$OUT_VERSION"
  else
    echo "Engine detect: FAILED for card${IDX} — leaving NONE (check debugfs + grep patterns)" >> "$CRT_LOG"
    DISPLAY_ENGINE="NONE"; DISPLAY_VERSION=""
  fi
  if [[ $AMD_IS_APU -ne 1 ]]; then
    if [[ -n "$LSPCI_LINE" ]] && echo "$LSPCI_LINE" | grep -qiE "$APU_NAMES_RE"; then
      AMD_IS_APU=1; APU_REASON="lspci APU codename"
    else
      local DRIVER VRAM_TOT="" GTT_TOT=""
      DRIVER="$(basename "$(readlink -f "$DEV/driver" 2>/dev/null)" 2>/dev/null || true)"
      if [ "$DRIVER" = "amdgpu" ]; then
        [ -r "$DEV/mem_info_vram_total" ] && VRAM_TOT="$(cat "$DEV/mem_info_vram_total")"
        [ -r "$DEV/mem_info_gtt_total" ] && GTT_TOT="$(cat "$DEV/mem_info_gtt_total")"
      fi
      if [[ "$VRAM_TOT" =~ ^[0-9]+$ && "$GTT_TOT" =~ ^[0-9]+$ ]] && \
         (( VRAM_TOT < 900000000 )) && (( GTT_TOT >= 256*1024*1024 )); then
        AMD_IS_APU=1; APU_REASON="UMA heuristic (small VRAM + large GTT)"
      else AMD_IS_APU=0; APU_REASON="${APU_REASON:-default (discrete or unknown)}"; fi
    fi
  fi
  if [ "${DISPLAY_ENGINE:-NONE}" = "NONE" ] && [ -r "$PCI_LIST" ]; then infer_from_pci_list "${VEN}" "${DEVHEX}" "$PCI_LIST" || true; fi
  if [ "${DISPLAY_ENGINE:-NONE}" = "NONE" ] && command -v lspci >/dev/null 2>&1; then
    name="$(lspci -s "${PCI_ADDR#0000:}" -nn 2>/dev/null | tr '[:upper:]' '[:lower:]')"
    if printf '%s' "$name" | grep -qE '(navi|rdna|sienna|navy[ _-]flounder|dimgrey[ _-]cavefish|beige[ _-]goby|arcturus|aldebaran|raven|renoir|cezanne|vangogh|yellow[ _-]carp|phoenix|raphael|strix)'; then
      DISPLAY_ENGINE="DCN"; DISPLAY_VERSION=""
      echo "Engine detect: caller safety net => DCN (from lspci name: $name)" >> "$CRT_LOG"
    elif printf '%s' "$name" | grep -qE '(polaris|tonga|hawaii|bonaire|pitcairn|tahiti|verde|oland|fiji|topaz|kabini|kaveri|carrizo|stoney|mullins)'; then
      DISPLAY_ENGINE="DCE"; DISPLAY_VERSION=""
      echo "Engine detect: caller safety net => DCE (from lspci name: $name)" >> "$CRT_LOG"
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
  is_amd_card "$CARD" || continue; found_any=1; process_card_prescan "$CARD"
done
if [[ $found_any -eq 0 ]]; then echo "!!!! BE CAREFUL: no AMD GPU detected !!!!"; fi ;;
	*)
		box_hash; box_center "${RED}YOUR CARD IS UNKNOWN${NOCOLOR}"
		box_center "Please report the detected PCI ID / lspci string above."; box_hash
		exit 1 ;;
esac
center_plain_log "Selected card = ${CHOSEN:-$selected_card}"
