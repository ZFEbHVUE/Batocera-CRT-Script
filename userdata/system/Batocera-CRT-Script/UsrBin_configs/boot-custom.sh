#!/bin/bash
# Runs via /etc/init.d/S00bootcustom very early in boot
# Generate /etc/X11/xorg.conf.d/15-crt-monitor.conf for CRT

LOG="/var/log/crt_boot.log"
CONF="/etc/X11/xorg.conf.d/15-crt-monitor.conf"
MON10="/etc/X11/xorg.conf.d/10-monitor.conf"

log(){ echo "[crt_boot] $*" >> "$LOG"; }

main() {
  # Run only on start
  [ "$1" = "start" ] || { log "arg=$1, nothing to do"; return 0; }

  # --- 1) Discover enabled output from 10-monitor.conf (no X needed) ---
  OUT=""
  if [ -f "$MON10" ]; then
    OUT="$(awk '
      BEGIN{s=0;id="";ign=0}
      /^[[:space:]]*Section[[:space:]]+"Monitor"/ {s=1;id="";ign=0;next}
      s && /^[[:space:]]*Identifier[[:space:]]+"/ {
        match($0,/Identifier[[:space:]]*"[^\"]+"/)
        if (RSTART) { id=substr($0,RSTART+length("Identifier \""),
                  RLENGTH-length("Identifier \"")-1) }
      }
      s && /Option[[:space:]]+"Ignore"[[:space:]]+"true"/ { ign=1 }
      s && /^[[:space:]]*EndSection/ { if (id!="" && ign==0) { print id; exit } s=0 }
    ' "$MON10")"
  fi

  # Fallback to DRM sysfs if not found
  if [ -z "$OUT" ]; then
    for d in /sys/class/drm/card*-*; do
      [ -e "$d/status" ] || continue
      if [ "$(cat "$d/status" 2>/dev/null)" = "connected" ]; then
        OUT="${d##*/}"; OUT="${OUT#card[0-9]-}"   # e.g. DVI-I-1
        break
      fi
    done
  fi
  if [ -z "$OUT" ]; then
    log "no enabled output found in $MON10 or DRM sysfs; abort"
    return 0
  fi

  # --- 2) Choose EDID file with precedence: custom.bin > cmdline > first file ---
  CMD="$(cat /proc/cmdline 2>/dev/null)"
  EDID_FILE_CMD="$(printf '%s\n' "$CMD" | sed -n 's/.*drm\.edid_firmware=[^ :]\+:edid\/\([^ ]\+\).*/\1/p' | head -n1)"

  if [ -f "/lib/firmware/edid/custom.bin" ]; then
    EDID_BIN="/lib/firmware/edid/custom.bin"
    EDID_SRC="custom.bin"
  elif [ -n "$EDID_FILE_CMD" ] && [ -f "/lib/firmware/edid/$EDID_FILE_CMD" ]; then
    EDID_BIN="/lib/firmware/edid/$EDID_FILE_CMD"
    EDID_SRC="$EDID_FILE_CMD"
  else
    EDID_BIN="$(ls /lib/firmware/edid/*.bin 2>/dev/null | head -n1)"
    EDID_SRC="$(basename "$EDID_BIN" 2>/dev/null)"
  fi

  # --- 3) Extract ranges from EDID (fallbacks if missing) ---
  VR=""; HR=""
  if [ -n "$EDID_BIN" ] && [ -f "$EDID_BIN" ]; then
    LINE="$(edid-decode "$EDID_BIN" 2>/dev/null | grep -m1 'Display Range Limits' || true)"
    VR="$(printf '%s\n' "$LINE" | sed -n 's/.* \([0-9][0-9]*\)-\([0-9][0-9]*\) Hz V.*/\1-\2/p')"
    HR="$(printf '%s\n' "$LINE" | sed -n 's/.* \([0-9][0-9]*\(\.[0-9]\)\?\)-\([0-9][0-9]*\(\.[0-9]\)\?\) kHz H.*/\1-\3/p')"
  fi
  [ -n "$VR" ] || VR="49-65"
  [ -n "$HR" ] || HR="15-16.5"

  # --- 4) Write the Xorg snippet BEFORE X starts ---
  mkdir -p /etc/X11/xorg.conf.d
  cat > "$CONF" <<EOF
Section "Monitor"
    Identifier  "CRT"
    VendorName  "BATOCERA_CRT_SCRIPT"
    HorizSync   $HR
    VertRefresh $VR
    Option      "DPMS" "False"
    Option      "DefaultModes" "False"
EndSection

Section "Device"
    Identifier "modesetting-amd-crt-bind"
    Driver "modesetting"
    Option "Monitor-$OUT" "CRT"
EndSection
EOF

  log "wrote $CONF (OUT=$OUT HS=$HR kHz VR=$VR Hz, EDID=$EDID_SRC)"
  return 0
}

main "$@"
