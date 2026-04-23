#!/bin/bash
#
# ES launcher shim for the HD/CRT Mode Switcher.
# Runs as a "game" from EmulationStation; opens an xterm with mode_switcher.sh.
#
# Wayland/HD mode: xterm -maximized lands on the wrong display when a CRT DAC
# is plugged in. Fix: inject a temporary labwc window rule that pins xterm to
# the primary video output, then clean up on exit.
#
# X11/CRT mode: ES renders a single splash frame via SDL then blocks in
# system(), leaving that frame frozen in the DRM scanout buffer.  The fix is
# es_settings.cfg HideWindow=true, which causes ES to fully deinit its window
# before running the command — releasing the DRM plane so xterm owns the
# display cleanly. The mode-switch backup/restore logic sets this automatically.

ADDED_RULE=0
RC="/userdata/system/.config/labwc/rc.xml"
RULE_ID="crt-mode-switcher"

cleanup_labwc_rule() {
    [ -f "$RC" ] || return 0
    grep -q "identifier=\"${RULE_ID}\"" "$RC" 2>/dev/null || return 0
    sed -i "/<windowRule identifier=\"${RULE_ID}\">/,/<\/windowRule>/d" "$RC" 2>/dev/null
    local pid; pid=$(pgrep -x labwc | head -1)
    [ -n "$pid" ] && kill -HUP "$pid" 2>/dev/null
}
trap cleanup_labwc_rule EXIT

if pgrep -x labwc >/dev/null 2>&1 && [ -f "$RC" ]; then
    PRIMARY=$(grep -m1 '^global.videooutput=' /userdata/system/batocera.conf 2>/dev/null | cut -d= -f2)
    if [ -n "$PRIMARY" ]; then
        # Remove any stale rule from a prior crash or double-launch
        sed -i "/<windowRule identifier=\"${RULE_ID}\">/,/<\/windowRule>/d" "$RC" 2>/dev/null
        sed -i 's|</windowRules>|    <windowRule identifier="'"${RULE_ID}"'">\n      <action name="MoveToOutput">\n        <output>'"$PRIMARY"'</output>\n      </action>\n      <action name="ToggleMaximize"/>\n    </windowRule>\n  </windowRules>|' "$RC"
        LABWC_PID=$(pgrep -x labwc | head -1)
        [ -n "$LABWC_PID" ] && kill -HUP "$LABWC_PID" 2>/dev/null
        sleep 0.3
        ADDED_RULE=1
    fi
fi

XTERM_NAME=""
[ "$ADDED_RULE" = "1" ] && XTERM_NAME="-name $RULE_ID"

DISPLAY=:0.0 xterm $XTERM_NAME -fs 15 -maximized \
    +sb -fg white -bg black -fa "DejaVuSansMono" -en UTF-8 \
    -e /userdata/system/Batocera-CRT-Script/Geometry_modeline/mode_switcher.sh

# cleanup_labwc_rule runs automatically via EXIT trap
