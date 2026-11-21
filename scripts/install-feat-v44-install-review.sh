#!/bin/bash
# TEMPORARY beta bootstrap. Delete this script after feat/v44-install-review merges to main.
# Installs the full Batocera-CRT-Script tree from the fork branch, then runs the v44 installer.
set -euo pipefail

REPO="net-terminal-gene/Batocera-CRT-Script"
BRANCH="feat/v44-install-review"
ZIP_URL="https://github.com/${REPO}/archive/refs/heads/${BRANCH}.zip"
ZIP_ROOT="Batocera-CRT-Script-feat-v44-install-review"
ZIP_FILE="/tmp/batocera-crt-${BRANCH//\//-}.zip"
DEST="/userdata/system/Batocera-CRT-Script"
ALLINONE="${DEST}/Batocera_ALLINONE"
INSTALLER="${ALLINONE}/Batocera-CRT-Script-v44.sh"

echo
echo "Downloading CRT Script (${BRANCH}) from ${REPO}..."
echo

if ! command -v unzip >/dev/null 2>&1; then
  echo "unzip is required but not installed." >&2
  exit 1
fi

curl --fail --location --progress-bar \
  --connect-timeout 15 \
  --retry 3 \
  --retry-delay 2 \
  --output "$ZIP_FILE" \
  "$ZIP_URL"

echo
echo "Download complete."
echo

preserve_dir="$(mktemp -d)"
overlay_keep="${preserve_dir}/batocera-save-crt-overlay"
phase_keep="${preserve_dir}/.install_phase"
if [ -f "${DEST}/batocera-save-crt-overlay" ] && [ ! -L "${DEST}/batocera-save-crt-overlay" ]; then
  cp -a "${DEST}/batocera-save-crt-overlay" "$overlay_keep"
fi
if [ -f "${DEST}/.install_phase" ] && [ ! -L "${DEST}/.install_phase" ]; then
  cp -a "${DEST}/.install_phase" "$phase_keep"
fi

rm -rf "$DEST" "/userdata/system/${ZIP_ROOT}"
unzip -qq "$ZIP_FILE" "${ZIP_ROOT}/userdata/system/Batocera-CRT-Script/*" -d /userdata/system/
mkdir -p "$DEST"
mv "/userdata/system/${ZIP_ROOT}/userdata/system/Batocera-CRT-Script/"* "$DEST/"
if [ -f "$overlay_keep" ]; then
  cp -a "$overlay_keep" "${DEST}/batocera-save-crt-overlay"
  chmod 755 "${DEST}/batocera-save-crt-overlay"
fi
if [ -f "$phase_keep" ]; then
  cp -a "$phase_keep" "${DEST}/.install_phase"
fi
rm -rf "$ZIP_FILE" "/userdata/system/${ZIP_ROOT}" "$preserve_dir"

if [ ! -f "$INSTALLER" ]; then
  echo "Expected installer not found: $INSTALLER" >&2
  exit 1
fi

chmod 755 "$INSTALLER"
find "${ALLINONE}/v44" -name '*.sh' -exec chmod 755 {} \;
if [ -f "${ALLINONE}/crt_script_selfcheck.sh" ]; then
  chmod 755 "${ALLINONE}/crt_script_selfcheck.sh"
fi

echo "Starting Batocera-CRT-Script-v44.sh..."
echo
exec "$INSTALLER"