# Batocera-CRT-Script v44 - step 01: tui helpers
# Terminal UI: colours, framed boxes (box_*, b71/e71, hbox), centred text and ENTER prompts.
# Menu input: ask/pick VAR MAX [e|b|d] reads a number 1..MAX until valid (e, b, d: ENTER accepted);
# num VAR MAX MSG reads an integer >= 0 (and <= MAX when MAX is not empty).
RED=${RED:-$'\033[31m'}; GREEN=${GREEN:-$'\033[32m'}; YELLOW=${YELLOW:-$'\033[33m'}; BLUE=${BLUE:-$'\033[1;34m'}
CYAN=${CYAN:-$'\033[36m'}; MAGENTA=${MAGENTA:-$'\033[35m'}; BOLD=${BOLD:-$'\033[1m'}; NOCOLOR=${NOCOLOR:-$'\033[0m'}
say_press_enter() { box_center "Press ${BLUE}ENTER${NOCOLOR} to continue…"; }
say_press_key() { box_center "Press ${BLUE}$1${NOCOLOR} to continue…"; }
ok_box() { box_hash; box_center "${GREEN}✔ $*${NOCOLOR}"; box_hash; }
warn_box() { box_hash; box_center "${YELLOW}⚠ $*${NOCOLOR}"; box_hash; }
err_box() { box_hash; box_center "${RED}✖ $*${NOCOLOR}"; box_hash; }
LOG_FILE="${LOG_FILE:-/dev/null}"
type _log_tee >/dev/null 2>&1 || _log_tee() { tee -a "$LOG_FILE"; }
if [ -t 1 ]; then
  cols=$(tput cols 2>/dev/null || printf "%s" 80)
else cols=80; fi
BOXW=$cols; [ "$BOXW" -lt 64 ] && BOXW=64; [ "$BOXW" -gt 110 ] && BOXW=110
border=$(printf "%${BOXW}s" | tr ' ' '#')
inner_w=$((BOXW - 4))
empty_line() { printf "##%*s##\n" "$inner_w" ""; }
center() {
  local s="$*"; local plain; plain="$(printf "%b" "$s" | sed 's/\x1B\[[0-9;]*[A-Za-z]//g')"; local slen=${#plain}
  if [ $slen -gt $inner_w ]; then
    s="$(printf "%b" "$s" | sed 's/\x1B\[[0-9;]*[A-Za-z]//g' | cut -c -$inner_w)"; plain="$s"; slen=${#plain}
  fi
  local left=$(( (inner_w - slen) / 2 ))
  local right=$(( inner_w - slen - left ))
  printf "##%*s%b%*s##\n" "$left" "" "$s" "$right" ""
}
center_plain() {
  local s="$*"; [ ${#s} -gt $BOXW ] && s="${s:0:$BOXW}"
  local left=$(( (BOXW - ${#s}) / 2 ))
  printf "%*s%s\n" "$left" "" "$s"
}
box_hash() { printf "%s\n" "$border" | _log_tee; }
box_empty() { empty_line | _log_tee; }
box_center() { center "$*" | _log_tee; }
b71() { echo "#######################################################################"; }
e71() { echo "##                                                                   ##"; }
hbox() { box_hash; box_center "$*"; box_hash; }
ask() { local _a; center_plain_log "Select option 1 to $2:"; read _a
  while [[ ! ${_a} =~ ^[1-$2]$ ]] && [[ -z ${3:-} || "$_a" != "" ]]; do center_plain_log "Select option 1 to $2:"; read _a; done
  printf -v "$1" '%s' "$_a"; }
pick() { local _a _m=":"
  case ${3:-} in b) _m=" or ENTER to bypass this configuration:" ;; d) _m=" or press ENTER for default: " ;; esac
  echo -n "                                  "; read _a
  while [[ ! ${_a} =~ ^[1-$2]$ ]] && [[ -z ${3:-} || "$_a" != "" ]]; do echo -n "Select option 1 to $2$_m"; read _a; done
  printf -v "$1" '%s' "$_a"; }
num() { local _a; echo -n "                                  "; read _a
  while [[ ! $_a =~ ^[0-9]+$ || "$_a" -lt 0 || ( -n $2 && "$_a" -gt $2 ) ]]; do echo -n "$3"; read _a; done
  printf -v "$1" '%s' "$_a"; }
box_left() {
  local s="$*"; s="${s//$'\t'/ }"; local plain; plain="$(printf "%b" "$s" | sed 's/\x1B\[[0-9;]*[A-Za-z]//g')"
  local eff_w=$(( inner_w - 1 ))
  if [ ${#plain} -gt "$eff_w" ]; then
    plain="${plain:0:$eff_w}"; s="$plain"
  fi
  local pad=$(( eff_w - ${#plain} ))
  printf '## %b%*s##\n' "$s" "$pad" '' | _log_tee
}
center_plain_log() { center_plain "$*" | _log_tee; }
prompt_centered_tty() {
  box_center "$*"
  if [ -e /dev/tty ]; then
    read -r </dev/tty || true
  else
    for s in 5 4 3 2 1; do
      box_center "Continuing in $s…"; sleep 1
    done
  fi
}
prompt_centered() {
  box_center "$*"; read -r
}
box_title() {
  box_hash; box_empty; box_center "$*"; box_empty; box_hash
}
type center_both >/dev/null 2>&1 || center_both() { center "$*" | _log_tee; }
