#!/usr/bin/env bash
# Records how the installer session ended. No Batocera target writes.
# All event values use fixed, allowlisted tokens. No shell commands, paths or secrets.
SESSION_STATE=collecting
SESSION_LAST_STEP=initialization
SESSION_EXIT_REASON=none
SESSION_TERMINAL_LOGGED=0

session_set_step() {
  [[ "${1:-}" =~ ^[A-Za-z0-9_.-]{1,48}$ ]] && SESSION_LAST_STEP="$1"
  return 0
}
session_set_state() {
  case "${1:-}" in collecting|applying|phase1_pending|verified_handoff|cancelled) SESSION_STATE="$1" ;; esac
  return 0
}
session_note_cancel() {
  case "${1:-}" in review_cancel|phase1_image_selection) SESSION_EXIT_REASON="$1" ;; *) SESSION_EXIT_REASON=user_cancelled ;; esac
  SESSION_STATE=cancelled
  return 0
}
session_emit_terminal() {
  local level="$1" outcome="$2" reason="$3" rc="$4"
  [[ "${SESSION_TERMINAL_LOGGED:-0}" == 1 ]] && return 0
  SESSION_TERMINAL_LOGGED=1
  if declare -F log_event >/dev/null 2>&1; then
    log_event "$level" installer session_finished outcome "$outcome" reason "$reason" stage "${SESSION_LAST_STEP:-unknown}" rc "$rc" || :
  fi
  return 0
}
session_verified_handoff() {
  local route="${1:-singleboot}"
  case "$route" in singleboot|phase2) ;; *) route=unknown ;; esac
  SESSION_STATE=verified_handoff
  SESSION_LAST_STEP=24_finish
  if declare -F log_event >/dev/null 2>&1; then
    log_event INFO installer installation_handoff route "$route" outcome verified reason persistence_unconfirmed || :
  fi
  # Explicit flush before a power-off or reboot command, which may never return.
  session_emit_terminal INFO verified_handoff shutdown_pending 0
}
session_phase1_handoff() {
  SESSION_STATE=phase1_pending
  SESSION_LAST_STEP=06_dualboot_phase1
  if declare -F log_event >/dev/null 2>&1; then
    log_event INFO 06_dualboot_phase1 phase1_handoff route phase1 outcome pending reason phase2_required || :
  fi
  # Phase 1 is not a completed CRT installation and has not passed the install check.
  session_emit_terminal INFO phase1_pending phase2_required 0
}
session_on_signal() {
  SESSION_EXIT_REASON="signal_$1"
  if [[ "${SESSION_TERMINAL_LOGGED:-0}" == 1 ]] && declare -F log_event >/dev/null 2>&1; then
    log_event WARN installer shutdown_interrupted outcome interrupted reason "$SESSION_EXIT_REASON" || :
  fi
  trap - INT TERM HUP
  exit "$2"
}
session_on_exit() {
  local rc="${1:-1}" state="${SESSION_STATE:-collecting}"
  trap - EXIT INT TERM HUP
  if [[ "${SESSION_TERMINAL_LOGGED:-0}" != 1 ]]; then
    if (( rc != 0 )); then
      local reason="${SESSION_EXIT_REASON:-none}"
      [[ "$reason" != none ]] || reason=nonzero_exit
      session_emit_terminal ERROR failed "$reason" "$rc"
    elif [[ "$state" == cancelled ]]; then
      session_emit_terminal INFO cancelled "${SESSION_EXIT_REASON:-user_cancelled}" 0
    else
      # A bare `exit 0` or normal fallthrough is NOT proof of completed install.
      session_emit_terminal WARN incomplete unexpected_zero_exit 0
    fi
  fi
  # Preserve the staged-file cleanup irrespective of status, and never mask the original rc.
  if declare -F stage_discard >/dev/null 2>&1; then
    stage_discard || :
  fi
  return 0
}
session_install_traps() {
  trap 'session_on_exit "$?"' EXIT
  trap 'session_on_signal int 130' INT
  trap 'session_on_signal term 143' TERM
  trap 'session_on_signal hup 129' HUP
  return 0
}
session_phase1_step() {
  local operation="$1"; shift
  session_set_step "$operation"
  if declare -F diag_run >/dev/null 2>&1; then
    diag_run 06_dualboot_phase1 "$operation" "$@"
  else
    "$@"
  fi
}
session_phase1_probes() {
  local path op
  for op in batocera rufomaculata linux initrd-crt.gz; do
    path="/boot/crt/$op"
    if declare -F diag_probe >/dev/null 2>&1; then
      case "$op" in
        batocera) diag_probe 06_dualboot_phase1 phase1_squashfs "$path" ;;
        rufomaculata) diag_probe 06_dualboot_phase1 phase1_board_image "$path" ;;
        linux) diag_probe 06_dualboot_phase1 phase1_kernel "$path" ;;
        *) diag_probe 06_dualboot_phase1 phase1_initrd "$path" ;;
      esac
    fi
  done
  return 0
}

session_shutdown_returned() {
  # Reaching this point does not tell us whether reboot/poweroff happened.
  local route="${1:-unknown}" rc="${2:-1}"
  case "$route" in phase2|singleboot) ;; *) route=unknown ;; esac
  [[ "$rc" =~ ^[0-9]{1,3}$ ]] || rc=1
  if declare -F log_event >/dev/null 2>&1; then
    log_event WARN installer shutdown_command_returned route "$route" outcome returned rc "$rc" || :
  fi
  return 0
}
