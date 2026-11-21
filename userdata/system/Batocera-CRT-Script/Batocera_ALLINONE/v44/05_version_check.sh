# Batocera-CRT-Script v44 - step 05: version check
# Batocera version check: v44 only (Version_of_batocera, TARGET_VER).
version_Batocera="$(batocera-es-swissknife --version 2>/dev/null || echo unknown)"
echo "Version batocera = ${version_Batocera}" >> "$CRT_LOG"
case "${version_Batocera}" in
  44*)
    echo "Version 44"; Version_of_batocera="v44"
    VERSION_BATOCERA_NUM=44 ;;
  *)
    echo "Unknown or unsupported Batocera version: ${version_Batocera}"; Version_of_batocera="unknown"
    VERSION_BATOCERA_NUM=0 ;;
esac
if declare -F log_event >/dev/null 2>&1; then
  if [ "$Version_of_batocera" = v44 ]; then log_event INFO 05_version_check version_check outcome ok || :;
  else log_event ERROR 05_version_check version_check outcome rejected || :; fi
fi
if [ "$Version_of_batocera" != "v44" ]; then
  box_hash; box_center "${RED}WRONG BATOCERA VERSION${NOCOLOR}"; box_center "This script requires Batocera v44."
  box_center "Detected: ${version_Batocera}"; box_center "Please use the correct script for your version."; box_hash
  exit 1
fi
version="${VERSION_BATOCERA_NUM}"
if ([ "$Version_of_batocera" == "v44" ]); then
{ TARGET_VER="44"; }
else { echo "Wrong Version"; }; fi
