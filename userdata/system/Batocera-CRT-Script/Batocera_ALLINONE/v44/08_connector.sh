
center_plain_log "Selected card = ${CHOSEN:-$selected_card}"


# Defined in 05_output_detect.sh. Runs after the GPU pre-scan in 07_gpu.sh.
output_detection_and_persist

# output_detection_and_persist already wrote 10-monitor.conf.
# video_output stays the name the rest of the installer already uses.

# Safety: make sure CHOSEN is set (the detector sets it globally)
if [ -z "${CHOSEN:-}" ]; then
  echo "ERROR: No connector selected (CHOSEN is empty). Did you call output_detection_and_persist earlier?"
  exit 1
fi

# Keep downstream compatibility with older code that used $video_output
video_output="${KERNEL_CONN_NAME:-$CHOSEN}"   # DRM name for syslinux [card_output]
video_output_xrandr="${video_output_xrandr:-$CHOSEN}"  # Xorg/xrandr name for X11 bits

# Bind the chosen connector to the AMD card that owns it.
# Purpose:
#   - Map the chosen connector (e.g., DP-1/HDMI-A-1) to its owning cardN
#   - Source /tmp/crt-detect/cardN.env written by 07_gpu.sh
#   - Show the APU banner and log a one-liner with connector -> card mapping
#
# Inputs:  video_output (the connector chosen by the user/detector), cardN.env files
# Outputs: Exports AMD_IS_APU, DISPLAY_ENGINE, DISPLAY_VERSION, AMD_CARD_INDEX, AMD_PCI_ADDR
# 09_monitor_edid.sh reads DISPLAY_ENGINE when it sets interlace parity and the EDID.
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

  
  # Not a card index. Sets OUT_ENGINE from the lspci name, then the lookup fails.
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

echo "CRT output selected: ${video_output}" | tee -a /userdata/system/logs/BUILD_15KHz_Batocera.log

