#!/bin/bash
# Videomode sync wrapper for the Batocera game launcher.
#
# videomodes.conf stores mode IDs at higher precision
# (e.g. 769x576.50.00060) than batocera-resolution currentMode reports
# (e.g. 769x576.50.00).  When global.videomode in batocera.conf carries the
# high-precision string, the launcher sees a mismatch and calls
# changeMode(), which triggers a spurious resolution switch on the CRT.
#
# This wrapper syncs global.videomode (and CRT.videomode if present) to match
# the actual current mode BEFORE the launcher reads the config, preventing
# the spurious mode change entirely.
#
# v44 replaced emulatorlauncher with batocera-launch. v43 still has the old name.

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

if command -v batocera-launch >/dev/null 2>&1; then
    exec batocera-launch "$@"
fi
exec emulatorlauncher "$@"
