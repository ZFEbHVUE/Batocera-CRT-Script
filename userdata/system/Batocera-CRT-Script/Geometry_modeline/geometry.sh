#!/bin/sh
# Compatibility entry point: the Geometry interface and engine now run in Python.
export DISPLAY="${DISPLAY:-:0.0}"
exec python3 -B /userdata/system/Batocera-CRT-Script/Geometry_modeline/geometry.py "$@"