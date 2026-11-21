#!/bin/bash
# Launch the CRT Script EmulationStation geometry tool directly.
# es_tool.sh provides a legacy xterm/dialog fallback if pygame is unavailable.
export DISPLAY="${DISPLAY:-:0.0}"
exec /userdata/system/Batocera-CRT-Script/Geometry_modeline/es_tool.sh
