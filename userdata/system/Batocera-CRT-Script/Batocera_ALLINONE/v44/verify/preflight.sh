#!/usr/bin/env bash
# Checks the installer files are present before any step is sourced.
# No target writes, no rollback, no native Batocera tool changes.
# This is sourced into the installer Bash scope.
preflight() {
  local directory="${1:-}" name missing=0
  local -a required=(
    01_tui_helpers.sh 02_amd_helpers.sh 03_final_message.sh
    04_backup_restore.sh 05_version_check.sh 06_dualboot_phase1.sh
    07_install_routing.sh 08_boot_custom.sh 09_output_detection.sh
    10_welcome.sh 11_graphics_card.sh 12_crt_output.sh
    13_monitor_edid.sh 14_rotation.sh 15_vendor_defaults.sh
    16_advanced_settings.sh 17_boot_config.sh 18_system_files.sh
    19_encoders_guncon.sh 20_crt_tools.sh 21_event_scripts.sh
    22_batocera_conf.sh 23_install_review.sh 24_finish.sh
    25_restore.sh edid_hold.sh
    log/diagnostics.sh log/session.sh
    verify/install.sh verify/preflight.sh verify/writes.sh verify/overlay.sh
  )
  [[ -d "$directory" ]] || return 1
  for name in "${required[@]}"; do
    if [[ ! -f "$directory/$name" || -L "$directory/$name" || ! -r "$directory/$name" || ! -s "$directory/$name" ]]; then
      missing=$((missing+1))
      # Avoid emitting arbitrary paths or content. Names come from the fixed list.
      # The log token cannot contain a slash, so log/events.sh is recorded as log_events.
      if declare -F log_event >/dev/null 2>&1; then
        log_event ERROR installer required_step_missing component "${name%.sh//\//_}" outcome failed || :
      fi
      printf 'CRT installer missing required install module: %s\n' "$name" >&2
    fi
  done
  if (( missing != 0 )); then
    printf 'CRT installer preflight failed: %s required module(s) unavailable.\n' "$missing" >&2
    return 1
  fi
  if declare -F log_event >/dev/null 2>&1; then
    log_event INFO installer source_layout_preflight outcome passed count "${#required[@]}" || :
  fi
  return 0
}
required_ok() {
  local module="${1:-installer}" operation="${2:-required_step}" rc="${3:-1}"
  [[ "$module" =~ ^[A-Za-z0-9_.-]{1,48}$ ]] || module=installer
  [[ "$operation" =~ ^[A-Za-z0-9_.-]{1,48}$ ]] || operation=required_step
  [[ "$rc" =~ ^[0-9]{1,3}$ ]] || rc=1
  (( rc == 0 )) && return 0
  if declare -F write_abort >/dev/null 2>&1; then
    write_abort "$module" "$operation" "$rc"
  fi
  printf 'CRT installer required step failed: %s/%s (rc=%s)\n' "$module" "$operation" "$rc" >&2
  exit "$rc"
}
source_ok() {
  required_ok "${1:-installer}" sourced_module "${2:-1}"
}
