# Batocera-CRT-Script v44 - step 07: install routing
# Entry routing: Phase 2 flag (X11 boot after Phase 1), Wayland -> Phase 1 then power-off,
# X11 -> standard install. Then the first-run backup or the "backup found" menu.
PHASE_FLAG="${CRTD}/.install_phase"; CRT_SCRIPT_DIR="${CRTD}"; IS_PHASE2=false; IS_DUALBOOT_INSTALL=false
detect_display_stack() {
  if [ -n "$(ls /run/user/*/wayland-* 2>/dev/null)" ] || pgrep -x labwc > /dev/null 2>&1; then
    DISPLAY_STACK="wayland"
  else DISPLAY_STACK="x11"; fi
}
_dualboot_installer_poweroff() {
  batocera-save-overlay 2>/dev/null || true; sync 2>/dev/null || true; sync 2>/dev/null || true
  echo o > /proc/sysrq-trigger
}
if [ -f "$PHASE_FLAG" ] && [ "$(cat "$PHASE_FLAG" 2>/dev/null)" = "2" ]; then
  IS_PHASE2=true; IS_DUALBOOT_INSTALL=true
  if grep -q 'OVERLAYFILE="/boot/boot/overlay"' /usr/bin/batocera-save-overlay 2>/dev/null; then
    sed -i 's|OVERLAYFILE="/boot/boot/overlay"|OVERLAYFILE="/boot/crt/overlay"|' /usr/bin/batocera-save-overlay
  fi
  hbox "Resuming CRT Script — Phase 2 of 2"; box_empty; box_center "X11 detected. Dual-boot is already configured."
  box_center "Continuing with CRT display setup..."; box_empty; box_hash; echo ""; sleep 2
else
  detect_display_stack
  if [ "$DISPLAY_STACK" = "wayland" ]; then
    if [ -f "$CHECK_FILE" ]; then
      box_hash; box_center "${BOLD}A previous installation was detected (Wayland)${NOCOLOR}"; box_empty
      box_center "Run the dual-boot installer again (Press 1)"; box_center "Restore to stock Batocera (Press 2)"
      box_empty; box_center "Your games and save files will ${GREEN}NOT${NOCOLOR} be deleted."; box_hash
      local wl_choice=""
      while :; do
        box_empty; box_center "Your choice [1/2]:"; box_empty
        if [ -e /dev/tty ]; then
          IFS= read -r wl_choice </dev/tty || wl_choice=""
        else IFS= read -r wl_choice || wl_choice=""; fi
        wl_choice="${wl_choice:-1}"
        case "$wl_choice" in
          1) break ;;
          2) restore_all; exit 0 ;;
          *) box_center "Please enter 1 or 2." ;;
        esac
      done
    fi
    box_hash; box_center "Wayland display stack detected."; box_center "X11 is required for CRT mode."; box_hash
    box_empty; box_center "A second X11 Batocera boot entry will be set up"
    box_center "alongside your existing Wayland install."; box_center "Your ROMs, saves, and BIOS files will be shared."
    box_empty; box_hash; echo ""; sleep 2; run_phase1; exit 0
  fi
fi
backup_restore_main || exit 1
