# Batocera-CRT-Script v44 - deploy batocera-save-crt-overlay for dual-boot Phase 2.
# Written during Phase 1; redeployed in Phase 2 if missing (e.g. script tree refresh via curl).
deploy_crt_overlay_script() {
  local log_step="${1:-06_dualboot_phase1}"
  local root="${CRT_SCRIPT_DIR:-/userdata/system/Batocera-CRT-Script}"
  local target="${root}/batocera-save-crt-overlay"
  if declare -F write_run >/dev/null 2>&1; then
    write_run "$log_step" overlay_writer_directory mkdir -p "$root"
  else
    mkdir -p "$root"
  fi
  if [ -L "$target" ]; then
    if declare -F write_abort >/dev/null 2>&1; then
      write_abort "$log_step" unsafe_overlay_writer_target 1
    fi
    return 1
  fi
  if ! cat > "$target" <<'OVERLAY_SCRIPT'
#!/bin/sh
OVERLAYFILE="/boot/crt/overlay"
OVERLAYMOUNT="/overlay/saved"
OVERLAYRAM="/overlay/overlay"
OVERLAYSIZE=100 # M

PATH=$PATH:/sbin

createOverlayIfNeeded() {
    COISIZE=$1
    test -e "${OVERLAYFILE}" && return 0
    echo "Creating an overlay file on the /boot filesystem..."
    dd if=/dev/zero of="${OVERLAYFILE}" bs=${COISIZE}M count=1 || return 1
    echo "Formating the overlay file in ext4..."
    mkfs.ext4 "${OVERLAYFILE}"                         || return 1
}

echo "Making /boot writable..."
if ! mount -o remount,rw /boot
then
    exit 1
fi

if test $# -eq 1
then
    if echo "$1" | grep -qE '[1-9][0-9]*'
       then
           echo "removing the existing overlay"
           rm -f "${OVERLAYFILE}" || exit 1
           OVERLAYSIZE=$1
    fi
fi

if ! createOverlayIfNeeded "${OVERLAYSIZE}"
then
    mount -o remount,ro /boot
    exit 1
fi

echo "Mounting the overlay file..."
if ! mount -o rw "${OVERLAYFILE}" "${OVERLAYMOUNT}"
then
    mount -o remount,ro /boot
    exit 1
fi

echo "Saving the real overlay to disk..."
if ! rsync -av --delete --exclude="/.cache" "${OVERLAYRAM}/" "${OVERLAYMOUNT}"
then
    umount "${OVERLAYMOUNT}"
    mount -o remount,ro /boot
    exit 1
fi

echo "Umounting the overlay file..."
if ! umount "${OVERLAYMOUNT}"
then
    mount -o remount,ro /boot
    exit 1
fi

echo "Making /boot read only..."
if ! mount -o remount,ro /boot
then
    exit 1
fi

echo "Synchronizing..."
sync

echo "Success."
exit 0
OVERLAY_SCRIPT
  then
    if declare -F write_abort >/dev/null 2>&1; then write_abort "$log_step" overlay_writer_write "$?"; fi
    return 1
  fi
  if declare -F write_run >/dev/null 2>&1; then
    write_run "$log_step" overlay_writer_permissions chmod 755 "$target"
  else
    chmod 755 "$target"
  fi
  if [ ! -f "$target" ] || [ ! -x "$target" ] || [ ! -s "$target" ]; then
    if declare -F write_abort >/dev/null 2>&1; then
      write_abort "$log_step" overlay_writer_readback 1
    fi
    return 1
  fi
  if declare -F ok_box >/dev/null 2>&1; then
    ok_box "batocera-save-crt-overlay deployed to ${target}"
  fi
  return 0
}