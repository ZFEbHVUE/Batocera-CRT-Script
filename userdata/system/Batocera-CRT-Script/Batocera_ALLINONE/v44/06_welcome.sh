

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[1;34m'
NOCOLOR='\033[0m'


BOOT_RESOLUTION=1
BOOT_RESOLUTION_ES=1

echo
echo "[$(date +"%H:%M:%S")]: BUILD_15KHz_Batocera START" > /userdata/system/logs/BUILD_15KHz_Batocera.log

########################################################################################
#####################        SERGI CLARA "NEW DEDICATION" Start #      #################
########################################################################################

# -------------------- Banner box --------------------
printf "%s\n" "$border"
empty_line
center "- DEDICATION -"
empty_line
center "IN MEMORY OF SERGI CLARA (PSAKHIS)"
empty_line
center "REST IN PEACE"
empty_line
printf "%s\n\n" "$border"

# -------------------- Centered context --------------------
center_plain "This release is dedicated to Sergi Clara (\"psakhis\") of GroovyArcade."
center_plain "He tragically passed away in a bicycle accident on October 9, 2024, at age 44."
center_plain "Sergi made major contributions to the CRT and retro-gaming community—"
center_plain "including GroovyMiSTer, GunCon2, RetroArch, and the wider Groovy/CRT Emudriver ecosystem."
center_plain "We extend our heartfelt condolences to his family and friends,"
center_plain "and we continue our work in his honor."
printf "\n"

center_plain "Selected threads and repositories that highlight his impact:"
printf "\n"

# -------------------- Centered references --------------------
center_plain "• GroovyMiSTer contributions:"
center_plain "  https://forum.arcadecontrols.com/index.php/topic,168163.0/all.html"
printf "\n"

center_plain "• \"CRT Emudriver – Non-emulated compatible games\""
center_plain "  (catalog of modern pixel-art titles that downscale cleanly to 15 kHz):"
center_plain "  https://forum.arcadecontrols.com/index.php/topic,161951.0/all.html"
printf "\n"

center_plain "• emu4crt (Mednafen mod) fork (continuing silmalik's work):"
center_plain "  https://forum.arcadecontrols.com/index.php/topic,155264.0/all.html"
printf "\n"

center_plain "• GunCon2 improvements (Linux & Windows), building on sonik's Windows driver:"
center_plain "  Forum: https://forum.arcadecontrols.com/index.php/topic,166121.0/all.html"
center_plain "  Code:  https://github.com/psakhis/guncon2"
printf "\n"

center_plain "• CRT Emudriver and Vulkan-related updates/discussion:"
center_plain "  https://forum.arcadecontrols.com/index.php/topic,161736.0/all.html"
printf "\n"

center_plain "Press ENTER to continue…"
read -r
echo
########################################################################################
#####################        SERGI CLARA "NEW DEDICATION" End #        #################
########################################################################################

########################################################################################
#####################          New Welcome Message Start               #################
########################################################################################

# --- Batocera CRT Script: Welcome (everything centered) ---

# Fallback ANSI colors if not predefined elsewhere in your script
RED=${RED:-"\033[31m"}
BLUE=${BLUE:-"\033[34m"}
NOCOLOR=${NOCOLOR:-"\033[0m"}

# -------------------- Banner box --------------------
printf "%s\n" "$border"
empty_line
center "BATOCERA CRT SCRIPT — 15 kHz / 25 kHz / 31 kHz for Batocera v44"
empty_line
center "Use at your own risk. The authors are not responsible for damage or data loss."
empty_line
center "Read the official Wiki and Installation Guide (links below)."
empty_line
center "Core team & acknowledgments"
empty_line
center "• ZFEbHVUE — Lead developer & main tester"
center "• Rion — CRT specialist & 15 kHz support"
center "• myzar — NVIDIA driver & compatibility"
center "• jfroco — Early CRT output for Batocera"
center "• rtissera — Enabled 15 kHz patches in Batocera"
center "• Substring — GroovyArcade maintainer (KMS/SDL work)"
center "• Calamity — 15 kHz Linux patches, CRT_EmuDriver, Switchres, GroovyMAME"
center "• D0023R (Doozer) — linux_kernel_15khz maintenance"
center "• dmanlcf — Maintains 15kHz kernel patches for Batocera"
center "• net_terminal_gene — HD/CRT Mode Switcher, Wayland/X11 dual-boot support"
empty_line
center "Hardware compatibility: check the Supported Cards pages (links below)."
empty_line
center "$(printf "%b" "${RED}")IMPORTANT — AMD Sea Islands (GCN 2.x / DCE 8.x):$(printf "%b" "${NOCOLOR}")"
center "Interlace is NOT supported on amdgpu. Use the radeon driver."
empty_line
center "$(printf "%b" "${RED}")NOTE — No 240p theme support:$(printf "%b" "${NOCOLOR}")"
center "320x240 boot resolution themes are not supported."
empty_line
center "If you accept these terms, press ENTER to continue."
empty_line
printf "%s\n" "$border"
printf "\n"

# -------------------- Centered links --------------------
center_plain "Documentation & Links"
center_plain "• Wiki (main):"
center_plain "  https://github.com/ZFEbHVUE/Batocera-CRT-Script/wiki"
printf "\n"

center_plain "• Installation Guide (wiki):"
center_plain "  https://github.com/ZFEbHVUE/Batocera-CRT-Script/wiki/Batocera-CRT-Script-Installation-Guide-%E2%80%90-Wired-Or-Wireless-Connection"
printf "\n"

center_plain "• Supported AMD dGPUs & APUs:"
center_plain "  https://github.com/ZFEbHVUE/Batocera-CRT-Script/wiki/Supported-AMD-dGPUs-&-APUs"
printf "\n"

center_plain "• Supported NVIDIA (Maxwell, proprietary driver):"
center_plain "  https://github.com/ZFEbHVUE/Batocera-CRT-Script/wiki/Supported-NVIDIA-Maxwell-Cards-%28Proprietary-Driver%29"
printf "\n"

# Long Sea Islands link: center if it fits, otherwise print full left-aligned (no trimming)
center_plain "• AMD Sea Islands (GCN 2.x / DCE 8.x) — use radeon (interlace unsupported on amdgpu):"
sea_link="https://github.com/ZFEbHVUE/Batocera-CRT-Script/wiki/Sea-Islands-(GCN-2.x---DCE-8.x):-Interlace-Unsupported-on-%60amdgpu%60-%E2%80%94-Use-%60radeon%60"

# Guard BOXW in case it's unset; always quote expansions
: "${BOXW:=0}"

if [ "${#sea_link}" -lt "${BOXW}" ]; then
  center_plain "  ${sea_link}"
else
  printf '%s\n' "  ${sea_link}"
fi
printf '\n'


# -------------------- Prompt (centered, no newline before read) --------------------
msg="PRESS ${BLUE}ENTER${NOCOLOR} TO START "
plain="$(printf "%b" "$msg" | sed 's/\x1B\[[0-9;]*[A-Za-z]//g')"
pad=$(( (BOXW - ${#plain}) / 2 ))
printf "%*s%b" "$pad" "" "$msg"
read -r
echo

########################################################################################
#####################            New Welcome Message End               #################
########################################################################################
