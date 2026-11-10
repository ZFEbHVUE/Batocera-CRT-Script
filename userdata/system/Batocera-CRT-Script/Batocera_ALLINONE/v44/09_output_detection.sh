# Batocera-CRT-Script v44 - step 09: output detection
# Output detection: xrandr name -> DRM connector (CONNECTOR_ID), X authority, the output menu and
# /etc/X11/xorg.conf.d/10-monitor.conf (written by persist_10_monitor_conf after confirm; an old file -> backup + reboot).
map_xrandr_to_drm() {
  local xr="$1"; local pref_card="${2:-${AMD_CARD_INDEX:-}}"; [ -z "$xr" ] && return 1
  local _LOG="${LOG_FILE:-/userdata/system/logs/BUILD_15KHz_Batocera.log}"
  local MAP_LOG_VERBOSE="${MAP_LOG_VERBOSE:-0}"
  _log() { echo "map_xrandr_to_drm: $*" >> "$_LOG"; }
  _log "------------------------------------------------------------"
  _log "XR input='${xr}'  pref_card='${pref_card:-*}'"; local cid=""
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
      else search_glob="/sys/class/drm/card*-*/connector_id"; fi
      shopt -s nullglob
      for f in $search_glob; do
        if [ -r "$f" ] && [ "$(cat "$f" 2>/dev/null)" = "$cid" ]; then
          match="${f%/connector_id}"; break
        fi
      done
      shopt -u nullglob
      if [ -n "$match" ]; then
        local base card_idx drm_out; base="$(basename -- "$match")"
        if [[ "$base" =~ ^card([0-9]+)-(.+)$ ]]; then
          card_idx="${BASH_REMATCH[1]}"; drm_out="${BASH_REMATCH[2]}"
          _log "CID match: XR='${xr}' CID=${cid} -> ${base} (card=${card_idx})"; printf '%s\n' "$drm_out"; return 0
        fi
      else _log "CID not found in sysfs for XR='${xr}' CID=${cid}; falling back to heuristic."; fi
    else _log "No CONNECTOR_ID for XR='${xr}'; falling back to heuristic."; fi
  else _log "xrandr not available; falling back to heuristic."; fi
  local xr_type_full xr_index_chain
  case "$xr" in
    DVI-I-*|DVI-D-*|DVI-A-*)
      xr_type_full="${xr%%-[0-9]*}"
      xr_index_chain="${xr#${xr_type_full}-}" ;;
    *)
      xr_type_full="${xr%%-*}"
      xr_index_chain="${xr#${xr_type_full}-}" ;;
  esac
  case "$xr_type_full" in
    DisplayPort) xr_type_full="DP" ;;
    USB-C|USBC|Type-C|USB) xr_type_full="DP" ;;
    HDMI-A|HDMI) : ;;
    DVI-I|DVI-D|DVI-A|DVI) : ;;
    eDP|LVDS|VGA) : ;;
    *) : ;;
  esac
  local best_exact="" best_exact_card=""; local best_family="" best_family_card="" best_family_rank=99
  shopt -s nullglob
  for p in /sys/class/drm/card*-*; do
    b="$(basename "$p")" || continue; [[ "$b" =~ ^card([0-9]+)-(.+)$ ]] || continue; card_idx="${BASH_REMATCH[1]}"
    drm_name="${BASH_REMATCH[2]}"
    if [[ "$drm_name" == DVI-*-* || "$drm_name" == HDMI-A-* ]]; then
      drm_type="${drm_name%%-[0-9]*}"; drm_idx_chain="${drm_name#${drm_type}-}"
    else
      drm_type="${drm_name%%-*}"; drm_idx_chain="${drm_name#${drm_type}-}"
    fi
    exact1="${drm_name}"
    case "$drm_type" in
      DP) alias2="DisplayPort-${drm_idx_chain}" ;;
      HDMI|HDMI-A) alias2="HDMI-${drm_idx_chain}" ;;
      DVI-I|DVI-D|DVI-A) alias2="DVI-${drm_idx_chain}" ;;
      *) alias2="" ;;
    esac
    if [ -n "$pref_card" ] && [ "$card_idx" != "$pref_card" ]; then continue; fi
    if [ "$xr" = "$exact1" ] || [ -n "$alias2" ] && [ "$xr" = "$alias2" ]; then
      best_exact="$drm_name"; best_exact_card="$card_idx"
      _log "EXACT alias: XR='${xr}' -> '${drm_name}' (card${card_idx})"
      if [ -n "$pref_card" ]; then
        printf '%s\n' "$best_exact"; return 0
      fi
      continue
    fi
    family_rank=99
    case "$xr_type_full" in
      DP)
        if [ "$drm_type" = "DP" ] && [ "$drm_idx_chain" = "$xr_index_chain" ]; then family_rank=0; fi ;;
      HDMI|HDMI-A)
        if { [ "$drm_type" = "HDMI-A" ] || [ "$drm_type" = "HDMI" ]; } \
           && [ "$drm_idx_chain" = "$xr_index_chain" ]; then family_rank=0; fi ;;
      DVI|DVI-I|DVI-D|DVI-A)
        if [[ "$drm_type" =~ ^DVI-(I|D|A)$ ]] && [ "$drm_idx_chain" = "$xr_index_chain" ]; then
          case "$drm_type" in
            DVI-I) family_rank=0 ;;
            DVI-D) family_rank=1 ;;
            DVI-A) family_rank=2 ;;
          esac
        fi ;;
      eDP|LVDS|VGA)
        if [ "$drm_type" = "$xr_type_full" ] && [ "$drm_idx_chain" = "$xr_index_chain" ]; then family_rank=0; fi ;;
    esac
    if [ "$family_rank" -lt "$best_family_rank" ]; then
      best_family="$drm_name"; best_family_card="$card_idx"; best_family_rank="$family_rank"
      _log "FAMILY candidate: XR='${xr}' -> '${drm_name}' (card${card_idx} rank=${family_rank})"
    fi
  done
  shopt -u nullglob
  if [ -n "$best_exact" ]; then
    _log "RESOLVE exact (card${best_exact_card}): '${best_exact}'"; printf '%s\n' "$best_exact"; return 0
  fi
  if [ -n "$best_family" ]; then
    _log "RESOLVE family (card${best_family_card} rank=${best_family_rank}): '${best_family}'"
    printf '%s\n' "$best_family"; return 0
  fi
  local guess=""
  case "$xr_type_full" in
    DisplayPort) guess="DP-${xr_index_chain}" ;;
    HDMI-A) guess="HDMI-A-${xr_index_chain}" ;;
    HDMI) guess="HDMI-A-${xr_index_chain}" ;;
    DVI-I|DVI-D|DVI-A) guess="${xr_type_full}-${xr_index_chain}" ;;
    DVI) guess="DVI-I-${xr_index_chain}" ;;
    eDP|LVDS|VGA) guess="${xr_type_full}-${xr_index_chain}" ;;
    USB-C|USBC|Type-C|USB) guess="DP-${xr_index_chain}" ;;
    *) guess="${xr_type_full}-${xr_index_chain}" ;;
  esac
  _log "RESOLVE guess: '${guess}'"; printf '%s\n' "$guess"; return 0
}
log_drm_map_snapshot() {
  echo "---- DRM connector snapshot (pref card: ${AMD_CARD_INDEX:-*}) ----" >> "$LOG_FILE"
  for p in /sys/class/drm/card*-*; do
    b="$(basename "$p")"; name="${b#card*-}"; t="${name%%-*}"; idx="${name#${t}-}"
    case "$t" in
      DP) xr1="DisplayPort-${idx}"; xr2="DP-${idx}" ;;
      HDMI|HDMI-A) xr1="HDMI-${idx}"; xr2="HDMI-A-${idx}" ;;
      DVI-I|DVI-D|DVI-A) xr1="${t}-${idx}"; xr2="DVI-${idx}" ;;
      *) xr1="${t}-${idx}"; xr2="" ;;
    esac
    if [ -n "${AMD_CARD_INDEX-}" ] && [[ "$b" != card${AMD_CARD_INDEX}-* ]]; then continue; fi
    echo "card${b#card}-  DRM:${name}  XR-candidates: ${xr1}${xr2:+, ${xr2}}" >> "$LOG_FILE"
  done
  echo "--------------------------------" >> "$LOG_FILE"
}
ensure_x_authority() {
  export DISPLAY="${DISPLAY:-:0}"
  if xrandr --query >/dev/null 2>&1; then return 0; fi
  local xauth=""; xauth="$(ps -eo args 2>/dev/null | grep -m1 -oE '/[^ ]*\.serverauth\.[0-9]+' || true)"
  if [ -z "$xauth" ] || [ ! -f "$xauth" ]; then xauth="$(ls -t /.serverauth.* /root/.serverauth.* /var/run/.serverauth.* 2>/dev/null | head -1)"; fi
  if [ -z "$xauth" ] || [ ! -f "$xauth" ]; then
    for cand in /root/.Xauthority "$HOME/.Xauthority" /tmp/.Xauthority; do [ -f "$cand" ] && { xauth="$cand"; break; }; done
  fi
  if [ -n "$xauth" ] && [ -f "$xauth" ]; then
    export XAUTHORITY="$xauth"
    echo "ensure_x_authority: using XAUTHORITY=$xauth" >> "${LOG_FILE:-/tmp/crt_script.log}" 2>/dev/null
  fi
  if ! xrandr --query >/dev/null 2>&1; then xhost +local: >/dev/null 2>&1 || true; fi
  xrandr --query >/dev/null 2>&1
}
output_detection_and_persist() {
  export LC_ALL=C; export LANG=C; export DISPLAY="${DISPLAY:-:0}"; ensure_x_authority; CONF_DIR="/etc/X11/xorg.conf.d"
  CONF_FILE="$CONF_DIR/10-monitor.conf"; FLAG_FILE="$CHECK_FILE"
  die() { echo "ERROR: $*" >&2; exit 1; }
  timestamp() { date +"%Y.%m.%d,%H.%M.%S"; }
  sanitize_conn() { sed 's/\r//g' | sed 's/[^A-Za-z0-9._:+-]//g'; }
  create_flag_file() { echo "$(timestamp)" > "$FLAG_FILE"; }
  box_title "Output detection (XRandR only)"; echo "XRandR-only path engaged" >> "$LOG_FILE"
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
        n="${ln%% *}"; st="${ln##* }"; [ -n "$n" ] || continue
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
    box_left "No outputs found via xrandr. Is X running?"; die "Cannot proceed without xrandr outputs."
  fi
  if [ -f "$CONF_FILE" ]; then
    box_hash; box_center "Existing Xorg monitor configuration detected:"; box_center "$CONF_FILE"; box_empty
    box_center "This file must be removed and the system must reboot before setup runs again."
    backup="${CONF_FILE}.$(timestamp)"; mv -- "$CONF_FILE" "$backup"; chmod 000 "$backup" || true
    box_center "Backed up to: $backup"; batocera-save-overlay >>"$LOG_FILE" 2>&1 || true; box_empty
    box_center "System will reboot to finish cleanup."; prompt_centered_tty "PRESS ${GREEN}ENTER${NOCOLOR} TO CONTINUE"
    box_hash; reboot; exit 0
  fi
  if [ ${#CONN_OUTS[@]} -eq 0 ]; then box_left "0 connected outputs reported by xrandr. You can still pick a port to keep active."; fi
    log_drm_map_snapshot
  box_empty; box_left "Detected outputs (xrandr):"; idx=1
  for o in "${ALL_OUTS[@]}"; do
    st="disconnected"
    if printf '%s\n' "${CONN_OUTS[@]}" | grep -qx "$o"; then st="connected"; fi
    box_left "  [$idx] $o  ($st)"
    idx=$((idx+1))
  done
  box_empty
  quick_rescan_outputs() {
	mapfile -t XR < <(DISPLAY=${DISPLAY:-:0} xrandr --query 2>/dev/null \
	  | awk '/^[^ ]+[[:space:]]+(connected|disconnected)/ {print $1, $2}' \
	  | grep -Eiv '^(Writeback|Virtual|VIRTUAL)')
    ALL_OUTS=()
    CONN_OUTS=()
    for ln in "${XR[@]}"; do
      n="${ln%% *}"; st="${ln##* }"; [ -n "$n" ] || continue
      [ "$st" = "connected" ] && CONN_OUTS+=("$n")
      ALL_OUTS+=("$n")
    done
    echo "Quick rescan: found ${#ALL_OUTS[@]} outputs; connected=${#CONN_OUTS[@]}" >> "$LOG_FILE"
  }
  while :; do
    box_hash; box_empty; box_center "Enter the number of the output you like to use for CRT output"
    box_center "(press R to rescan outputs once via xrandr)"; box_empty; box_hash
    pad=$(( (BOXW / 2) - 2 ))
    [ "$pad" -lt 0 ] && pad=0; read -rp "$(printf '%*s> ' "$pad")" sel
    if [[ "$sel" =~ ^[Rr]$ ]]; then
      hbox "Rescanning outputs (single xrandr --query)…"; quick_rescan_outputs
        log_drm_map_snapshot
      box_empty; box_center "Detected outputs (xrandr)"; idx=1
      for o in "${ALL_OUTS[@]}"; do
        st="disconnected"
        if printf '%s\n' "${CONN_OUTS[@]}" | grep -qx "$o"; then st="connected"; fi
        box_center "  [$idx] $o  ($st)"
        idx=$((idx+1))
      done
      box_empty; continue
    fi
    if ! [[ "$sel" =~ ^[0-9]+$ ]]; then
      box_center "Please enter a number (or press R to rescan)."; continue
    fi
    if ! { [ "$sel" -ge 1 ] && [ "$sel" -le ${#ALL_OUTS[@]} ]; }; then
      box_center "Out of range. Valid: 1..${#ALL_OUTS[@]} (or press R to rescan)."; continue
    fi
    CHOSEN="${ALL_OUTS[$((sel-1))]}"
  video_output_xrandr="$CHOSEN"; KERNEL_CONN_NAME="$(map_xrandr_to_drm "$CHOSEN" "${AMD_CARD_INDEX:-}")"
  echo "XR->DRM mapping: '$CHOSEN' -> '${KERNEL_CONN_NAME}'" >> "$LOG_FILE"
  if ! compgen -G "/sys/class/drm/card${AMD_CARD_INDEX:-*}-${KERNEL_CONN_NAME}" >/dev/null; then
    echo "WARN: Could not verify DRM connector card${AMD_CARD_INDEX:-*}-${KERNEL_CONN_NAME} in sysfs." >> "$LOG_FILE"
    box_center "Warning: couldn't verify ${KERNEL_CONN_NAME} under /sys/class/drm. Using it anyway."
  fi
  box_empty; box_center "Selected output (XR): ${BLUE}${video_output_xrandr}${NOCOLOR}"
  box_center "Kernel connector (DRM/syslinux): ${GREEN}${KERNEL_CONN_NAME}${NOCOLOR}"; box_empty; break
done
  sleep 1
  if DISPLAY=:0 xrandr --query >/dev/null 2>&1; then
    chosen_status="$(DISPLAY=:0 xrandr --query | awk -v c="$CHOSEN" '$1==c {print $2; exit}')"
    if [ "$chosen_status" != "connected" ]; then
      box_left "${CHOSEN} is currently reported as DISCONNECTED by xrandr. Proceeding anyway."
    else box_left "${CHOSEN} is CONNECTED."; fi
  fi
  OTHERS=()
  for o in "${ALL_OUTS[@]}"; do [ "$o" != "$CHOSEN" ] && OTHERS+=("$o"); done
  echo "Output recorded. 10-monitor.conf waits until confirm. Keep: $CHOSEN Ignored: ${OTHERS[*]}" >> "$LOG_FILE"
  echo "Selected output: $CHOSEN"; echo "  Ignored: ${OTHERS[*]}"; echo
}
persist_10_monitor_conf() {
  local CONF_DIR="/etc/X11/xorg.conf.d" CONF_FILE="$CONF_DIR/10-monitor.conf" o
  [ -n "${CHOSEN:-}" ] || { echo "ERROR: No CRT output selected." >&2; exit 1; }
  mkdir -p "$CONF_DIR"
  {
    echo "# Generated by Batocera-CRT-Script (XRandR-only)"; echo "# Disables all outputs except the selected one"; echo
    for o in "${OTHERS[@]}"; do
      o="$(printf '%s' "$o" | sanitize_conn)"; echo 'Section "Monitor"'; echo "    Identifier \"$o\""
      echo '    Option "Ignore" "true"'; echo 'EndSection'; echo
    done
    echo 'Section "Monitor"'; echo "    Identifier \"$(printf '%s' "$CHOSEN" | sanitize_conn)\""; echo 'EndSection'
    echo
  } > "$CONF_FILE"
  chmod 644 "$CONF_FILE"
  echo "Wrote $CONF_FILE after confirm" >> "$LOG_FILE"
}
