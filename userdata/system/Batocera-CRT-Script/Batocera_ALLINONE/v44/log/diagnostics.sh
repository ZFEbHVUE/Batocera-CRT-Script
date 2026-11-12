#!/usr/bin/env bash
# Extra diagnostic events. Writes only through the event log.
# Does not change the installer return or error handling.
# Never log raw command lines, user paths, file contents or device IDs.

diag_event() {
  # module event operation outcome [rc]; event names are defined by call sites.
  local module="${1:-}" event="${2:-}" operation="${3:-}" outcome="${4:-}" rc="${5:-}"
  declare -F log_event >/dev/null 2>&1 || return 0
  if [[ "$rc" =~ ^[0-9]{1,3}$ ]]; then
    log_event "$([[ "$outcome" == failed || "$outcome" == missing ]] && echo ERROR || echo INFO)" "$module" "$event" operation "$operation" outcome "$outcome" rc "$rc" || :
  else
    log_event "$([[ "$outcome" == failed || "$outcome" == missing ]] && echo ERROR || echo INFO)" "$module" "$event" operation "$operation" outcome "$outcome" || :
  fi
  return 0
}

diag_run() {
  # Same stdout, stderr and return status as the wrapped command; no set -e.
  local module="$1" operation="$2" rc
  shift 2
  if declare -F log_run >/dev/null 2>&1; then
    log_run "$module" "$operation" "$@"
    return $?
  fi
  "$@"; rc=$?; return "$rc"
}

diag_probe() {
  # A nonempty regular file is present, NOT proof that its contents are correct.
  local module="$1" operation="$2" path="$3"
  if [[ -f "$path" && -s "$path" && ! -L "$path" ]]; then
    diag_event "$module" file_presence "$operation" present
  else
    diag_event "$module" file_presence "$operation" missing
  fi
  return 0
}

diag_probe_key() {
  # Fixed literal config keys only. Never copy values into the diagnostic log.
  local module="$1" operation="$2" path="$3" literal="$4"
  if [[ -f "$path" ]] && grep -Fqx -- "$literal" "$path" 2>/dev/null; then
    diag_event "$module" configuration_key "$operation" present
  else
    diag_event "$module" configuration_key "$operation" missing
  fi
  return 0
}

diag_context() {
  # Explicitly safe, coarse selection summary. No usernames, PCI paths or raw INI.
  local route vendor driver output monitor res orient
  route=singleboot
  [[ "${IS_PHASE2:-false}" == true ]] && route=phase2
  case "${TYPE_OF_CARD:-}" in
    'AMD/ATI'|AMD) vendor=amd ;;
    NVIDIA) vendor=nvidia ;;
    INTEL|Intel) vendor=intel ;;
    *) vendor=unknown ;;
  esac
  case "${drivers_type:-${Drivers_Nvidia_CHOICE:-}}" in
    AMDGPU|amdgpu) driver=amdgpu ;;
    RADEON|radeon) driver=radeon ;;
    NOUVEAU|nouveau) driver=nouveau ;;
    Nvidia_Drivers|NVIDIA_DRIVERS) driver=nvidia ;;
    *) driver=unspecified ;;
  esac
  log_event INFO installer confirmed_configuration route "$route" component "$vendor" operation "$driver" || :
  # Only typical XRandR connector identifiers, never arbitrary strings.
  output=${video_output:-}
  if [[ "$output" =~ ^(DP|HDMI|HDMI-A|DVI-I|DVI-D|DVI-A|VGA|eDP|LVDS)-[0-9]+(-[0-9]+)*$ ]]; then
    log_event INFO installer confirmed_output component "$output" || :
  else
    log_event INFO installer confirmed_output component unknown || :
  fi
  monitor=${monitor_firmware:-}
  if [[ "$monitor" =~ ^[a-zA-Z][a-zA-Z0-9_]{0,31}$ ]]; then
    log_event INFO installer confirmed_monitor component "$monitor" || :
  else
    log_event INFO installer confirmed_monitor component unknown || :
  fi
  # Resolution is whitelisted; '@' is encoded in a fixed, harmless token.
  res=${EDID_resolution:-}
  if [[ "$res" =~ ^[0-9]{3,4}x[0-9]{3,4}@[0-9]{2,3}$ ]]; then
    res=${res//@/_at_}
    log_event INFO installer confirmed_boot_resolution component "$res" || :
  else
    log_event INFO installer confirmed_boot_resolution component unspecified || :
  fi
  case "${ES_rotation:-}" in NORMAL|INVERTED|RIGHT|LEFT) orient=${ES_rotation,,} ;; *) orient=unknown ;; esac
  log_event INFO installer confirmed_es_rotation operation "$orient" || :
  if declare -p CRT_ENCODER_NAMES >/dev/null 2>&1; then
    local enc=${#CRT_ENCODER_NAMES[@]}
    if [[ "$enc" =~ ^[0-9]{1,3}$ ]]; then
      log_event INFO installer confirmed_encoders count "$enc" || :
    fi
  fi
  # Detailed dotclocks, GunCon2, custom crt_range and ES offsets are logged
  # by upstream log_confirmed_settings once, after confirmation.
  return 0
}

diag_pre_shutdown() {
  local mode="${1:-singleboot}"
  # Called only after the pre-save and post-save checks have passed.
  # A verified handoff does NOT assert reboot-time persistence or CRT signal.
  if declare -F session_verified_handoff >/dev/null 2>&1; then
    session_verified_handoff "$mode"
  elif declare -F log_event >/dev/null 2>&1; then
    log_event WARN installer installation_handoff route "$mode" outcome unverified reason diagnostic_helper_missing || :
  fi
  return 0
}
