# Batocera-CRT-Script v44 - holds the new EDID, its switchres.ini copy, and BootRes.log until confirm.
# Sourced into the existing installer shell. Targets are never written during selection.
STAGE_DIR=""
STAGE_ORIGINAL_SWITCHRES=""
STAGE_WORK_SWITCHRES=""
STAGE_BOOTRES=""
STAGE_EDID=""
STAGE_SOURCE_SWITCHRES=""
STAGE_KEEP_FAILED=0

stage_discard() {
  if [ -n "${STAGE_DIR:-}" ] && [ -d "$STAGE_DIR" ] && [ "${STAGE_KEEP_FAILED:-0}" -ne 1 ]; then
    rm -rf -- "$STAGE_DIR"
  fi
  STAGE_DIR="" STAGE_ORIGINAL_SWITCHRES="" STAGE_WORK_SWITCHRES=""
  STAGE_BOOTRES="" STAGE_EDID="" STAGE_SOURCE_SWITCHRES=""
  CRT_GEOMETRY_SNAPSHOT=""
  STAGE_KEEP_FAILED=0
}

stage_begin() {
  local source_ini="$1"
  stage_discard
  [ -f "$source_ini" ] && [ ! -L "$source_ini" ] || return 1
  STAGE_DIR=$(mktemp -d "${TMPDIR:-/tmp}/crt-review.XXXXXXXX") || return 1
  chmod 700 "$STAGE_DIR" || return 1
  STAGE_SOURCE_SWITCHRES="$source_ini"
  STAGE_ORIGINAL_SWITCHRES="$STAGE_DIR/original_switchres.ini"
  STAGE_WORK_SWITCHRES="$STAGE_DIR/switchres.ini"
  STAGE_BOOTRES="$STAGE_DIR/BootRes.log"
  cp -p -- "$source_ini" "$STAGE_ORIGINAL_SWITCHRES" || return 1
  cp -p -- "$source_ini" "$STAGE_WORK_SWITCHRES" || return 1
  CRT_GEOMETRY_SNAPSHOT="$STAGE_ORIGINAL_SWITCHRES"
  return 0
}

# Minimal offline EDID integrity: valid header, 128-byte blocks, correct checksums,
# and consistent extension count. Prevent replacing a calibrated EDID with corrupt data.
stage_valid_edid() {
  local file="$1" size header
  [ -f "$file" ] && [ ! -L "$file" ] || return 1
  size=$(wc -c < "$file") || return 1
  [[ "$size" =~ ^[0-9]+$ ]] || return 1
  (( size >= 128 && size <= 4096 && size % 128 == 0 )) || return 1
  header=$(od -An -tx1 -N8 "$file" | tr -d '[:space:]') || return 1
  [ "$header" = "00ffffffffffff00" ] || return 1
  od -An -tu1 -v "$file" | awk -v blocks="$((size / 128))" '
    { for (i=1; i<=NF; i++) {
      n++; x=$i; sum+=x;
      if (n == 127) extensions=x;
      if (n % 128 == 0) { if (sum % 256 != 0) bad=1; sum=0; }
    }}
    END { exit !(n == blocks*128 && extensions == blocks-1 && !bad) }
  '
}

# Single-file, same-directory staging. Never follow symlink targets.
stage_install() {
  local source="$1" target="$2" mode="$3" directory temp
  directory=$(dirname -- "$target") || return 1
  [ -f "$source" ] && [ ! -L "$source" ] && [ ! -L "$target" ] || return 1
  [ -d "$directory" ] && [ ! -L "$directory" ] || return 1
  temp=$(mktemp "${target}.stage.XXXXXXXX") || return 1
  if ! cp -- "$source" "$temp" || ! chmod "$mode" "$temp" || ! cmp -s -- "$source" "$temp" || ! mv -f -- "$temp" "$target"; then
    rm -f -- "$temp"
    return 1
  fi
  return 0
}

stage_commit() {
  local selected_name="$1" edid_dir="$2" bootres_target="$3" edid_target old_edid="" old_bootres=""
  # Only a previously selected built-in monitor profile or the literal custom.bin.
  [[ "$selected_name" =~ ^[A-Za-z0-9_-]+\.bin$ ]] || return 1
  [ -n "${STAGE_DIR:-}" ] && [ -d "$STAGE_DIR" ] || return 1
  [ "${STAGE_EDID:-}" = "$STAGE_DIR/$selected_name" ] || return 1
  stage_valid_edid "$STAGE_EDID" && [ -s "$STAGE_BOOTRES" ] || return 1
  # Stop if another process or wizard action changed original calibration while reviewing.
  cmp -s -- "$STAGE_SOURCE_SWITCHRES" "$STAGE_ORIGINAL_SWITCHRES" || return 1
  [ -d "$edid_dir" ] || return 1
  edid_target="$edid_dir/$selected_name"
  [ ! -L "$edid_target" ] && [ ! -L "$bootres_target" ] || return 1
  if [ -e "$edid_target" ]; then
    [ -f "$edid_target" ] || return 1
    old_edid="$STAGE_DIR/existing_edid.bin"
    cp -p -- "$edid_target" "$old_edid" || return 1
  fi
  if [ -e "$bootres_target" ]; then
    [ -f "$bootres_target" ] || return 1
    old_bootres="$STAGE_DIR/existing_BootRes.log"
    cp -p -- "$bootres_target" "$old_bootres" || return 1
  fi
  stage_install "$STAGE_EDID" "$edid_target" 644 || return 1
  if ! stage_install "$STAGE_BOOTRES" "$bootres_target" 644; then
    # Roll back EDID on failure to preserve previously active calibration.
    if [ -n "$old_edid" ]; then
      if ! stage_install "$old_edid" "$edid_target" 644; then
        STAGE_KEEP_FAILED=1
        printf '%s\n' "CRT review EDID rollback failed: backup retained at $old_edid" >&2
      fi
    elif ! rm -f -- "$edid_target"; then
      STAGE_KEEP_FAILED=1
      printf '%s\n' "CRT review new EDID cleanup failed: $edid_target" >&2
    fi
    return 1
  fi
  return 0
}
