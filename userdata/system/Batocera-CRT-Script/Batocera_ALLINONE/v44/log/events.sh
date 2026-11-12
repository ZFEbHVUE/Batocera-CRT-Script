#!/usr/bin/env bash
# Diagnostic event log. Optional. Sourcing defines functions only.
# This file defines functions only; sourcing has no filesystem side effects.
# Never pass raw configuration values, command arguments, credentials or paths.

log_init() {
  local root="${1:-/userdata/system/logs}" stamp path
  [[ -d "$root" && -w "$root" ]] || return 1
  stamp=$(date -u '+%Y%m%dT%H%M%SZ') || return 1
  path=$(umask 077; mktemp "${root}/CRT_Install_${stamp}_XXXXXX.log") || return 1
  chmod 600 "$path" || { rm -f -- "$path"; return 1; }
  LOG_PATH=$path
  LOG_RUN_ID=${path##*/}
  LOG_RUN_ID=${LOG_RUN_ID%.log}
  # Hold an already-open file descriptor instead of reopening a replaceable path.
  if ! exec {LOG_FD}>>"$path"; then
    rm -f -- "$path"
    unset LOG_PATH LOG_RUN_ID
    return 1
  fi
  log_event INFO installer session_started phase unknown || return 1
}

# A bad event is recorded as a short error. The rejected value is not written.
log_reject_event() {
  local reason="$1" now
  if [[ -n "${LOG_FD:-}" ]]; then
    now=$(date -u '+%Y-%m-%dT%H:%M:%SZ') || now=unknown
    printf '%s run=%s level=ERROR module=log_events event=logging_event_rejected reason=%s\n' \
      "$now" "${LOG_RUN_ID:-unknown}" "$reason" >&"$LOG_FD" || :
  fi
  return 2
}

log_event() {
  local level="${1:-}" module="${2:-}" name="${3:-}" key value line now
  (( $# >= 3 )) || { log_reject_event missing_arguments; return 2; }
  shift 3
  [[ "$level" =~ ^(DEBUG|INFO|WARN|ERROR)$ ]] || { log_reject_event invalid_level; return 2; }
  [[ "$module" =~ ^[a-zA-Z0-9_.-]{1,48}$ ]] || { log_reject_event invalid_module; return 2; }
  [[ "$name" =~ ^[a-zA-Z0-9_.-]{1,64}$ ]] || { log_reject_event invalid_event; return 2; }
  (( $# % 2 == 0 )) || { log_reject_event odd_fields; return 2; }
  line=""
  while (( $# )); do
    key=$1; value=$2; shift 2
    case "$key" in
      phase|rc|outcome|operation|reason|choice|component|stage|count|route|checked|matched|missing|mismatch|mhz|pixels|hz) ;;
      range)
        [[ "$value" =~ ^[0-9.,-]{1,160}$ ]] || { log_reject_event invalid_value; return 2; }
        line+=" $key=$value"
        continue
        ;;
      *) log_reject_event invalid_field; return 2 ;;
    esac
    [[ "$value" =~ ^[a-zA-Z0-9_.-]{1,64}$ ]] || { log_reject_event invalid_value; return 2; }
    line+=" $key=$value"
  done
  [[ -n "${LOG_FD:-}" ]] || return 0
  now=$(date -u '+%Y-%m-%dT%H:%M:%SZ') || return 1
  printf '%s run=%s level=%s module=%s event=%s%s\n' \
    "$now" "${LOG_RUN_ID:-unknown}" "$level" "$module" "$name" "$line" >&"$LOG_FD"
}

log_confirmed_settings() {
  local clock_name clock_value width_name width_value
  for clock_name in dotclock_min dotclock_min_mame; do
    clock_value=${!clock_name:-}
    if [[ "$clock_value" =~ ^[0-9]{1,3}$ ]]; then
      log_event INFO installer "confirmed_${clock_name}" mhz "$clock_value" || :
    else
      log_event INFO installer "confirmed_${clock_name}" operation unspecified || :
    fi
  done
  for width_name in super_width super_width_mame; do
    width_value=${!width_name:-}
    if [[ "$width_value" =~ ^[0-9]{1,6}$ ]]; then
      log_event INFO installer "confirmed_${width_name}" pixels "$width_value" || :
    else
      log_event INFO installer "confirmed_${width_name}" operation unspecified || :
    fi
  done
  if [[ "${Guncon2_x:-}" =~ ^[0-9]{1,6}$ && "${Guncon2_y:-}" =~ ^[0-9]{1,6}$ && "${Guncon2_freq:-}" =~ ^[0-9]{1,3}$ ]]; then
    log_event INFO installer confirmed_guncon2_resolution pixels "${Guncon2_x}" || :
    log_event INFO installer confirmed_guncon2_height pixels "${Guncon2_y}" || :
    log_event INFO installer confirmed_guncon2_frequency hz "${Guncon2_freq}" || :
  fi
  if [[ "${polling_rate:-}" == 'usbhid.jspoll=1 xpad.cpoll=1' ]]; then
    log_event INFO installer confirmed_usb_polling operation enabled || :
  else
    log_event INFO installer confirmed_usb_polling operation default || :
  fi
  local profile_name range_name range_value range_count es_file es_key es_line es_value
  if [[ "${CRT_KEEP_GEOMETRY:-0}" == 1 ]]; then
    log_event INFO installer confirmed_geometry operation keep || :
    log_event INFO installer confirmed_monitor_profile component custom || :
    range_count=0
    while read -r range_name range_value; do
      [[ -n "$range_name" ]] || continue
      if [[ "$range_name" =~ ^crt_range[0-9]+$ && "$range_value" =~ ^[0-9.,-]{1,160}$ ]]; then
        log_event INFO installer confirmed_crt_range component "$range_name" range "$range_value" || :
        range_count=$((range_count + 1))
      fi
    done <<< "${CRT_GEOMETRY_RANGES:-}"
    if (( range_count == 0 )); then
      log_event INFO installer confirmed_crt_range operation unspecified || :
    fi
  else
    log_event INFO installer confirmed_geometry operation new_profile || :
    profile_name=${monitor_firmware:-}
    if [[ "$profile_name" =~ ^[a-zA-Z0-9_.-]{1,64}$ ]]; then
      log_event INFO installer confirmed_monitor_profile component "$profile_name" || :
    else
      log_event INFO installer confirmed_monitor_profile operation unspecified || :
    fi
  fi
  if [[ "${CRT_KEEP_ES_POSITION:-0}" == 1 && -s "${CRT_PRIOR_ES_ARGS:-}" ]]; then
    log_event INFO installer confirmed_es_position operation keep || :
    es_file=$CRT_PRIOR_ES_ARGS
  else
    log_event INFO installer confirmed_es_position operation reset || :
    es_file=""
  fi
  for es_key in screenoffset_x screenoffset_y screensizeoffset_x screensizeoffset_y; do
    es_value=""
    if [[ -n "$es_file" ]]; then
      es_line=$(grep -E "^${es_key}[[:space:]]" "$es_file" 2>/dev/null | head -1)
      es_value=${es_line#"$es_key"}
      es_value=${es_value#"${es_value%%[![:space:]]*}"}
    else
      es_value=0
    fi
    if [[ "$es_value" =~ ^-?[0-9]{1,4}$ ]]; then
      log_event INFO installer "confirmed_${es_key}" pixels "$es_value" || :
    else
      log_event INFO installer "confirmed_${es_key}" operation unspecified || :
    fi
  done
}

log_module_begin() {
  if declare -F session_set_step >/dev/null 2>&1; then session_set_step "$1"; fi
  log_event INFO "$1" module_source_started stage sourced || :
}
log_module_end() {
  local module=$1 rc=$2
  if (( rc == 0 )); then
    log_event INFO "$module" module_source_returned outcome ok rc "$rc" || :
  else
    log_event ERROR "$module" module_source_returned outcome nonzero rc "$rc" || :
  fi
  # No claim that a return code of zero proves installation success.
  return 0
}
log_run() {
  local module=$1 operation=$2 rc
  shift 2
  log_event INFO "$module" command_started operation "$operation" || :
  "$@"; rc=$?
  if (( rc == 0 )); then
    log_event INFO "$module" command_returned operation "$operation" outcome ok rc "$rc" || :
  else
    log_event ERROR "$module" command_returned operation "$operation" outcome failed rc "$rc" || :
  fi
  return "$rc"
}
