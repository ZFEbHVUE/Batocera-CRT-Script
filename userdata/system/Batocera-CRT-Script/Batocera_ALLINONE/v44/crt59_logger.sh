#!/usr/bin/env bash
# v44 Phase 59 diagnostic events, optional, silent, shell-scope preserving.
# This file defines functions only; sourcing has no filesystem side effects.
# Never pass raw configuration values, command arguments, credentials or paths.

crt59_init() {
  local root="${1:-/userdata/system/logs}" stamp path
  [[ -d "$root" && -w "$root" ]] || return 1
  stamp=$(date -u '+%Y%m%dT%H%M%SZ') || return 1
  path=$(umask 077; mktemp "${root}/CRT_Install_${stamp}_XXXXXX.log") || return 1
  chmod 600 "$path" || { rm -f -- "$path"; return 1; }
  CRT59_LOG_PATH=$path
  CRT59_RUN_ID=${path##*/}
  CRT59_RUN_ID=${CRT59_RUN_ID%.log}
  # Hold an already-open file descriptor instead of reopening a replaceable path.
  if ! exec {CRT59_LOG_FD}>>"$path"; then
    rm -f -- "$path"
    unset CRT59_LOG_PATH CRT59_RUN_ID
    return 1
  fi
  crt59_event INFO installer session_started phase unknown || return 1
}

# A bad event is recorded as a short error. The rejected value is not written.
crt59_reject_event() {
  local reason="$1" now
  if [[ -n "${CRT59_LOG_FD:-}" ]]; then
    now=$(date -u '+%Y-%m-%dT%H:%M:%SZ') || now=unknown
    printf '%s run=%s level=ERROR module=crt59_logger event=logging_event_rejected reason=%s\n' \
      "$now" "${CRT59_RUN_ID:-unknown}" "$reason" >&"$CRT59_LOG_FD" || :
  fi
  return 2
}

crt59_event() {
  local level="${1:-}" module="${2:-}" name="${3:-}" key value line now
  (( $# >= 3 )) || { crt59_reject_event missing_arguments; return 2; }
  shift 3
  [[ "$level" =~ ^(DEBUG|INFO|WARN|ERROR)$ ]] || { crt59_reject_event invalid_level; return 2; }
  [[ "$module" =~ ^[a-zA-Z0-9_.-]{1,48}$ ]] || { crt59_reject_event invalid_module; return 2; }
  [[ "$name" =~ ^[a-zA-Z0-9_.-]{1,64}$ ]] || { crt59_reject_event invalid_event; return 2; }
  (( $# % 2 == 0 )) || { crt59_reject_event odd_fields; return 2; }
  line=""
  while (( $# )); do
    key=$1; value=$2; shift 2
    case "$key" in
      phase|rc|outcome|operation|reason|choice|component|stage|count|route|checked|matched|missing|mismatch|mhz|pixels|hz) ;;
      *) crt59_reject_event invalid_field; return 2 ;;
    esac
    [[ "$value" =~ ^[a-zA-Z0-9_.-]{1,64}$ ]] || { crt59_reject_event invalid_value; return 2; }
    line+=" $key=$value"
  done
  [[ -n "${CRT59_LOG_FD:-}" ]] || return 0
  now=$(date -u '+%Y-%m-%dT%H:%M:%SZ') || return 1
  printf '%s run=%s level=%s module=%s event=%s%s\n' \
    "$now" "${CRT59_RUN_ID:-unknown}" "$level" "$module" "$name" "$line" >&"$CRT59_LOG_FD"
}

crt59_log_confirmed_settings() {
  local clock_name clock_value width_name width_value
  for clock_name in dotclock_min dotclock_min_mame; do
    clock_value=${!clock_name:-}
    if [[ "$clock_value" =~ ^[0-9]{1,3}$ ]]; then
      crt59_event INFO installer "confirmed_${clock_name}" mhz "$clock_value" || :
    else
      crt59_event INFO installer "confirmed_${clock_name}" operation unspecified || :
    fi
  done
  for width_name in super_width super_width_mame; do
    width_value=${!width_name:-}
    if [[ "$width_value" =~ ^[0-9]{1,6}$ ]]; then
      crt59_event INFO installer "confirmed_${width_name}" pixels "$width_value" || :
    else
      crt59_event INFO installer "confirmed_${width_name}" operation unspecified || :
    fi
  done
  if [[ "${Guncon2_x:-}" =~ ^[0-9]{1,6}$ && "${Guncon2_y:-}" =~ ^[0-9]{1,6}$ && "${Guncon2_freq:-}" =~ ^[0-9]{1,3}$ ]]; then
    crt59_event INFO installer confirmed_guncon2_resolution pixels "${Guncon2_x}" || :
    crt59_event INFO installer confirmed_guncon2_height pixels "${Guncon2_y}" || :
    crt59_event INFO installer confirmed_guncon2_frequency hz "${Guncon2_freq}" || :
  fi
  if [[ "${polling_rate:-}" == 'usbhid.jspoll=1 xpad.cpoll=1' ]]; then
    crt59_event INFO installer confirmed_usb_polling operation enabled || :
  else
    crt59_event INFO installer confirmed_usb_polling operation default || :
  fi
}

crt59_module_begin() {
  crt59_event INFO "$1" module_source_started stage sourced || :
}
crt59_module_end() {
  local module=$1 rc=$2
  if (( rc == 0 )); then
    crt59_event INFO "$module" module_source_returned outcome ok rc "$rc" || :
  else
    crt59_event ERROR "$module" module_source_returned outcome nonzero rc "$rc" || :
  fi
  # No claim that a return code of zero proves installation success.
  return 0
}
crt59_run() {
  local module=$1 operation=$2 rc
  shift 2
  crt59_event INFO "$module" command_started operation "$operation" || :
  "$@"; rc=$?
  if (( rc == 0 )); then
    crt59_event INFO "$module" command_returned operation "$operation" outcome ok rc "$rc" || :
  else
    crt59_event ERROR "$module" command_returned operation "$operation" outcome failed rc "$rc" || :
  fi
  return "$rc"
}
