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

crt59_event() {
  local level="${1:-}" module="${2:-}" name="${3:-}" key value line now
  (( $# >= 3 )) || return 2
  shift 3
  [[ "$level" =~ ^(DEBUG|INFO|WARN|ERROR)$ ]] || return 2
  [[ "$module" =~ ^[a-zA-Z0-9_.-]{1,48}$ ]] || return 2
  [[ "$name" =~ ^[a-zA-Z0-9_.-]{1,64}$ ]] || return 2
  (( $# % 2 == 0 )) || return 2
  [[ -n "${CRT59_LOG_FD:-}" ]] || return 0  # logging optional
  now=$(date -u '+%Y-%m-%dT%H:%M:%SZ') || return 1
  line="$now run=${CRT59_RUN_ID:-unknown} level=$level module=$module event=$name"
  while (( $# )); do
    key=$1; value=$2; shift 2
    case "$key" in
      phase|rc|outcome|operation|reason|choice|component|stage|count|route) ;;
      *) return 2 ;;
    esac
    [[ "$value" =~ ^[a-zA-Z0-9_.-]{1,64}$ ]] || return 2
    line+=" $key=$value"
  done
  printf '%s\n' "$line" >&"$CRT59_LOG_FD"
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
