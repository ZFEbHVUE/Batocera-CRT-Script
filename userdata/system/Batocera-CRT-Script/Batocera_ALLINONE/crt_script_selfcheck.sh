#!/bin/bash
# crt_script_selfcheck.sh — BusyBox-safe, strips color tags, fixed-string checks
set -euo pipefail

say(){ printf "%b\n" "$*"; }
ok(){ say "✅  $*"; }
bad(){ say "❌  $*"; }

LOG="/userdata/system/logs/BUILD_15KHz_Batocera.log"
FSH="/userdata/system/scripts/first_script.sh"
MON="/etc/X11/xorg.conf.d/10-monitor.conf"

# --- Sanitizers ---
# 1) strip real ANSI ESC sequences (ESC [ ... letter)
ESC=$'\033'
strip_ansi(){ sed -E "s/${ESC}\[[0-9;]*[A-Za-z]//g"; }
# 2) strip literal bracket color tags like: [1;34m ... [0m
strip_bracket_colors(){ sed -E 's/\[[0-9;]*m//g'; }
# 3) drop non-printables and trailing spaces / hashes
strip_np_tail(){ tr -cd '[:print:]\n' | sed -E 's/[[:space:]#]+$//'; }

clean(){ strip_ansi | strip_bracket_colors | strip_np_tail; }

# Keep only text after the last colon and clean it
just_conn(){ sed -E 's/.*: *//' | clean; }

# --- 1) Read chosen connectors from the log (and clean) ---
XR_CHOSEN="$(grep -m1 -oE 'Selected output \(XR\): .*'        "$LOG" | just_conn)"
DRM_CHOSEN="$(grep -m1 -oE 'Kernel connector \(DRM/syslinux\): .*' "$LOG" | just_conn)"

[ -n "${XR_CHOSEN:-}" ]  && ok "XR (from log): $XR_CHOSEN"   || { bad "XR chosen not found in log"; exit 1; }
[ -n "${DRM_CHOSEN:-}" ] && ok "DRM (from log): $DRM_CHOSEN" || { bad "DRM chosen not found in log"; exit 1; }

# --- 2) XRandR: does the connector exist? ---
XR_LIST="$(xrandr --query | awk '/ (connected|disconnected)/{print $1}' | clean)"
if printf '%s\n' "$XR_LIST" | grep -Fxq "$XR_CHOSEN"; then
  ok "XR exists in xrandr: $XR_CHOSEN"
else
  bad "XR not in xrandr: $XR_CHOSEN"
  say  "    xrandr connectors: $(printf '%s' "$XR_LIST" | paste -sd' ')"
fi

# --- 3) DRM: check suffix list like DP-1, HDMI-A-1, DVI-I-1, … ---
DRM_LIST="$(ls /sys/class/drm | sed -nE 's/^card[0-9]+-//p' | sort -u | clean)"
DRM_OK=0
if printf '%s\n' "$DRM_LIST" | grep -Fxq "$DRM_CHOSEN"; then
  DRM_OK=1
elif [[ "$DRM_CHOSEN" =~ ^HDMI-[0-9]+$ ]] && printf '%s\n' "$DRM_LIST" | grep -Fxq "${DRM_CHOSEN/HDMI-/HDMI-A-}"; then
  DRM_OK=1
fi
[ $DRM_OK -eq 1 ] && ok "DRM exists in /sys/class/drm: $DRM_CHOSEN" \
                  || { bad "DRM not found under /sys/class/drm: $DRM_CHOSEN"; say "    Nearby: $(printf '%s' "$DRM_LIST" | paste -sd' ')"; }

# 4) Kernel cmdline (info only)
CMD="$(cat /proc/cmdline)"
VID_ARG="$(printf '%s' "$CMD" | tr ' ' '\n' | awk '/^video=/{print; exit}')"
EDID_ARG="$(printf '%s' "$CMD" | tr ' ' '\n' | awk '/^drm\.edid_firmware=/{print; exit}')"
say "Kernel args: ${VID_ARG:-<none>}  ${EDID_ARG:-<none>}"

if [ -n "$VID_ARG" ]; then
  grep -Fq "video=${DRM_CHOSEN}:e" <<<"$VID_ARG" && ok "syslinux video= uses DRM: ${DRM_CHOSEN}" || bad "syslinux video= mismatch (expected ${DRM_CHOSEN})"
else
  say "ℹ️  No video= yet (likely pre-reboot)"
fi
if [ -n "$EDID_ARG" ]; then
  grep -Fq "drm.edid_firmware=${DRM_CHOSEN}:" <<<"$EDID_ARG" && ok "syslinux drm.edid_firmware uses DRM: ${DRM_CHOSEN}" || bad "syslinux drm.edid_firmware mismatch (expected ${DRM_CHOSEN})"
fi

# --- 5) syslinux.cfg files: look for both strings (fixed string search) ---
FOUND_ERR=0
while IFS= read -r cfg; do
  [ -s "$cfg" ] || continue
  if grep -Fq "video=${DRM_CHOSEN}:e" "$cfg" && grep -Fq "drm.edid_firmware=${DRM_CHOSEN}:" "$cfg"; then
    ok "syslinux OK: $cfg"
  else
    bad "syslinux mismatch: $cfg"
    L="$(grep -F 'APPEND' "$cfg" | tr '\n' ' ' | clean)"
    say "    -> $L"
    FOUND_ERR=1
  fi
done < <(find /boot -maxdepth 3 -type f -name 'syslinux.cfg' 2>/dev/null)

# --- 6) first_script.sh must target the XR name ---
if grep -Fq -- "--output ${XR_CHOSEN}" "$FSH"; then
  ok "first_script.sh targets XR: ${XR_CHOSEN}"
else
  bad "first_script.sh does not target XR: ${XR_CHOSEN}"
  grep -nF -- '--output' "$FSH" || true
fi

# --- 7b) List ignored outputs from 10-monitor.conf ---
# Build a list of Identifier values for sections that set: Option "Ignore" "true"
IGNORED_LIST="$(
  awk '
    /^[[:space:]]*Section "Monitor"/ { id=""; ign=0; next }
    /^[[:space:]]*Identifier "[^"]+"/ {
      s=$0
      sub(/^[[:space:]]*Identifier "[^"]*"/,"",s)   # throwaway; we just need to extract
      # robust extract:
      if (match($0,/Identifier "[^"]+"/)) {
        t=substr($0,RSTART,RLENGTH)
        sub(/^Identifier "/,"",t)
        sub(/"$/,"",t)
        id=t
      }
      next
    }
    /Option[[:space:]]+"Ignore"[[:space:]]+"true"/ { ign=1; next }
    /^[[:space:]]*EndSection/ { if (ign && id!="") print id; next }
  ' "$MON" 2>/dev/null
)"

IGNORED_COUNT="$(printf '%s\n' "$IGNORED_LIST" | sed '/^$/d' | wc -l)"

if [ "$IGNORED_COUNT" -gt 0 ]; then
  say "Other outputs ignored in 10-monitor.conf: $IGNORED_COUNT"
  # one-line list: DP-1 HDMI-1 DVI-D-1 ...
  say "Ignored outputs: $(printf '%s' "$IGNORED_LIST" | paste -sd' ' -)"
else
  say "Other outputs ignored in 10-monitor.conf: 0"
fi

[ $FOUND_ERR -eq 0 ] && ok "Self-check complete" || bad "Self-check found syslinux mismatches"
