#!/bin/bash
# Videomode sync wrapper for emulatorlauncher.
#
# videomodes.conf stores mode IDs at higher precision
# (e.g. 769x576.50.00060) than batocera-resolution currentMode reports
# (e.g. 769x576.50.00).  When global.videomode in batocera.conf carries the
# high-precision string, emulatorlauncher sees a mismatch and calls
# changeMode(), which triggers a spurious resolution switch on the CRT.
#
# This wrapper syncs global.videomode (and CRT.videomode if present) to match
# the actual current mode BEFORE emulatorlauncher reads the config, preventing
# the spurious mode change entirely.

export DISPLAY="${DISPLAY:-:0.0}"
CURRENT=$(batocera-resolution currentMode 2>/dev/null)
if [ -n "$CURRENT" ]; then
    CONF=/userdata/system/batocera.conf
    if grep -q "^global.videomode=" "$CONF" 2>/dev/null; then
        sed -i "s|^global.videomode=.*|global.videomode=$CURRENT|" "$CONF"
    fi
    if grep -q "^CRT.videomode=" "$CONF" 2>/dev/null; then
        sed -i "s|^CRT.videomode=.*|CRT.videomode=$CURRENT|" "$CONF"
    fi
fi

exec emulatorlauncher "$@"
