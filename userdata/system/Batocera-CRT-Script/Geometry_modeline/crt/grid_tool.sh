#!/bin/sh
# No terminal/dialog UI is kept behind the native grid.
export DISPLAY="${DISPLAY:-:0.0}"
exec python3 -B /userdata/system/Batocera-CRT-Script/Geometry_modeline/grid_tool.py "$@"
