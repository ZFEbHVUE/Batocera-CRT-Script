#!/bin/bash
# Batocera CRT Script - EmulationStation visual centering/scaling launcher.
#
# The visual tool is based on Sirmagb's EScentred UI concept and is adapted
# for the CRT Script's existing es.arg.override backend. If pygame is not
# available, fall back to the previous dialog/xterm implementation.

export DISPLAY="${DISPLAY:-:0.0}"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PY_TOOL="${SCRIPT_DIR}/es_tool.py"
LEGACY_TOOL="${SCRIPT_DIR}/es_tool_legacy.sh"
LOG_FILE="/userdata/system/logs/es_tool.log"

mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

if command -v python3 >/dev/null 2>&1 && \
   python3 -c 'import pygame' >/dev/null 2>&1 && \
   [ -f "$PY_TOOL" ]; then
    exec python3 "$PY_TOOL" "$@"
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - Visual ES geometry tool unavailable; using legacy dialog tool." >> "$LOG_FILE" 2>&1

if [ -f "$LEGACY_TOOL" ]; then
    exec xterm -fs 15 -maximized -fg white -bg black -fa "DejaVuSansMono" -en UTF-8 \
        -e bash "$LEGACY_TOOL"
fi

echo "ERROR: Neither visual nor legacy ES geometry tool is available." >> "$LOG_FILE" 2>&1
exit 1
