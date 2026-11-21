#!/usr/bin/env bash
# Stops the install when a required write fails, and stages those writes until the check passes.
# Only allowlisted module/operation tokens reach the structured diagnostic log.
# Do not wrap or modify native Batocera utilities.
write_abort() {
  local module="${1:-installer}" operation="${2:-unknown}" rc="${3:-1}"
  [[ "$module" =~ ^[A-Za-z0-9_.-]{1,48}$ ]] || module=installer
  [[ "$operation" =~ ^[A-Za-z0-9_.-]{1,48}$ ]] || operation=unknown
  [[ "$rc" =~ ^[0-9]{1,3}$ ]] || rc=1
  (( rc != 0 )) || rc=1
  if declare -F session_set_step >/dev/null 2>&1; then session_set_step "$module" || :; fi
  if declare -F log_event >/dev/null 2>&1; then
    log_event ERROR "$module" mandatory_write_failed operation "$operation" outcome failed rc "$rc" || :
  fi
  printf 'CRT installation stopped: mandatory operation failed (%s/%s, rc=%s)\n' "$module" "$operation" "$rc" >&2
  exit "$rc"
}
write_run() {
  local module="$1" operation="$2" rc
  shift 2
  if declare -F diag_run >/dev/null 2>&1; then
    diag_run "$module" "$operation" "$@"
    rc=$?
  else
    "$@"; rc=$?
  fi
  (( rc == 0 )) || write_abort "$module" "$operation" "$rc"
  return 0
}
write_append_matches() {
  # Assert that the CRT label exists exactly once and has exactly one expected
  # APPEND; do not emit its arguments (they contain private connector details).
  local file="$1" expected="$2"
  awk -v expected="$expected" '
    /^LABEL crt$/ { nlabel++; active=1; next }
    /^LABEL / { active=0 }
    active && /^[[:space:]]*APPEND[[:space:]]/ {
      nappend++; line=$0; sub(/^[[:space:]]*APPEND[[:space:]]+/, "", line)
      if (line != expected) bad=1
    }
    END { exit !(nlabel==1 && nappend==1 && bad==0) }
  ' "$file"
}

# Sourced at startup, but the write function is only called after Confirm.
# No native Batocera utility or standalone CRT tool is replaced.
write_generate() {
  # module operation octal-mode destination command [arguments...]
  local module="$1" operation="$2" mode="$3" destination="$4" dir temp rc
  shift 4
  dir="${destination%/*}"
  # No silent overwrite through a symlink, no relative destinations.
  if [[ "$destination" != /* || "$dir" == "$destination" || ! -d "$dir" || -L "$dir" || -L "$destination" || -d "$destination" ]]; then
    write_abort "$module" "${operation}_destination" 1
  fi
  temp="$(umask 077; mktemp "${dir}/.write-${operation}.XXXXXXXX")" || write_abort "$module" "${operation}_stage" 1
  # Capture the generator's true exit code, not the result of a later chmod.
  if declare -F diag_run >/dev/null 2>&1; then
    diag_run "$module" "$operation" "$@" > "$temp"
    rc=$?
  else
    "$@" > "$temp"
    rc=$?
  fi
  if (( rc != 0 )) || [[ ! -s "$temp" || -L "$temp" ]]; then
    rm -f -- "$temp"
    (( rc != 0 )) || rc=1
    write_abort "$module" "${operation}_generate" "$rc"
  fi
  chmod "$mode" "$temp"
  rc=$?
  if (( rc != 0 )); then
    rm -f -- "$temp"
    write_abort "$module" "${operation}_chmod" "$rc"
  fi
  mv -f -- "$temp" "$destination"
  rc=$?
  if (( rc != 0 )); then
    rm -f -- "$temp"
    write_abort "$module" "${operation}_install" "$rc"
  fi
  if [[ ! -f "$destination" || ! -s "$destination" || -L "$destination" ]]; then
    write_abort "$module" "${operation}_readback" 1
  fi
  return 0
}
