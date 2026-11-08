# Batocera-CRT-Script v44 - step 22: batocera conf
# batocera.conf CRT block (videomode/output, ES, RetroArch, systems), es.arg.override, mode backups,
# MAME ini files and TATE settings.
if [ ! -f "/userdata/system/batocera.conf.bak" ];then cp /userdata/system/batocera.conf /userdata/system/batocera.conf.bak; fi
LINE_NO=$(sed -n '/## ES Settings, See wiki page on how to center EmulationStation/{=;q;}' /userdata/system/batocera.conf.bak)
if [ -z "$LINE_NO" ]; then
	cp /userdata/system/batocera.conf.bak /userdata/system/batocera.conf
else
	truncate -s 0 batocera.conf
	sed -n "1,$(( LINE_NO - 1 )) p; $LINE_NO q" /userdata/system/batocera.conf.bak > /userdata/system/batocera.conf
fi
MODE_BACKUP_BASE="/userdata/Batocera-CRT-Script-Backup/mode_backups"
_hd_videomode=$(batocera-settings-get global.videomode 2>/dev/null || true)
_hd_videooutput=$(batocera-settings-get global.videooutput 2>/dev/null || true)
mkdir -p "${MODE_BACKUP_BASE}/hd_mode/video_settings"
if [ ! -s "${MODE_BACKUP_BASE}/hd_mode/video_settings/hd_mode_list.txt" ]; then
echo "global.videomode=${_hd_videomode:-default}" \
    > "${MODE_BACKUP_BASE}/hd_mode/video_settings/video_mode.txt"
fi
echo "${_hd_videooutput}" \
    > "${MODE_BACKUP_BASE}/hd_mode/video_settings/video_output.txt"
_crt_boot_line=$(grep "Boot_" /userdata/system/videomodes.conf 2>/dev/null \
    | grep "^${H_RES_EDID}x${V_RES_EDID}\." | head -1)
_crt_boot_mode="${_crt_boot_line%%:*}"
file="/userdata/system/es.arg.override"
screensizeoffset_x_new=00; screensizeoffset_y_new=00; screenoffset_x_new=00; screenoffset_y_new=00
if [ -f "$file" ]; then rm $file; fi
touch $file; echo "screensizeoffset_x $screensizeoffset_x_new" > "$file"
echo "screensizeoffset_y $screensizeoffset_y_new" >> "$file"; echo "screenoffset_x $screenoffset_x_new" >> "$file"
echo "screenoffset_y $screenoffset_y_new" >> "$file"; chmod 644 $file
file_BatoceraConf="/userdata/system/batocera.conf"
append_crt_script_settings_start() {
	{
		echo "###################################################"; echo "## CRT Script Settings Start"
		echo "###################################################"
		echo "## ES Settings, See wiki page on how to center EmulationStation"
	} >> "$file_BatoceraConf"
}
append_fbneo_tate_settings() {
	{
		echo "###################################################"; echo "##  FBNEO CORE TATE SETTINGS"
		echo "###################################################"; echo "fbneo.video_allow_rotate=off"
		echo "###################################################"; echo "## CRT Script Settings End"
		echo "###################################################"
	} >> "$file_BatoceraConf"
}
if [ -n "$_crt_boot_mode" ]; then
    sed -i '/^global\.videomode=/d' "$file_BatoceraConf"
    echo "global.videomode=$_crt_boot_mode" >> "$file_BatoceraConf"
fi
if [ -n "$video_output_xrandr" ]; then
    sed -i '/^global\.videooutput=/d' "$file_BatoceraConf"
    echo "global.videooutput=$video_output_xrandr" >> "$file_BatoceraConf"
fi
mkdir -p "${MODE_BACKUP_BASE}/crt_mode/video_settings"
if [ -n "$_crt_boot_mode" ]; then
    echo "global.videomode=$_crt_boot_mode" \
        > "${MODE_BACKUP_BASE}/crt_mode/video_settings/video_mode.txt"
fi
if [ -n "$video_output_xrandr" ]; then
    echo "global.videooutput=$video_output_xrandr" \
        > "${MODE_BACKUP_BASE}/crt_mode/video_settings/video_output.txt"
fi
if [ "$BOOT_RESOLUTION_ES" == "1" ]; then echo $Resolution_es >> "$file_BatoceraConf"; fi
# Resolution_es is a calculated rate with a .000 suffix. It matches no key in
# batocera-resolution listModes, so EmulationStation shows AUTO and does not
# keep the mode picked for this monitor. Use the videomodes.conf key instead,
# in batocera.conf and in the boot file that the first CRT boot actually applies.
if [ -n "$_crt_boot_mode" ]; then
    sed -i '/^es\.resolution=/d' "$file_BatoceraConf"; echo "es.resolution=$_crt_boot_mode" >> "$file_BatoceraConf"
    if [ "${BOOT_RESOLUTION:-0}" = "1" ] && [ -f /boot/batocera-boot.conf ]; then
        mount -o remount,rw /boot 2>/dev/null || true
        sed -i "s|.*es\\.resolution=.*|es.resolution=${_crt_boot_mode}|" /boot/batocera-boot.conf
        echo "es.resolution set to videomodes key ${_crt_boot_mode}" >> "$CRT_LOG"
    fi
fi
append_crt_script_settings_start
if [ "$ES_rotation" == "NORMAL" ] || [ "$ES_rotation" == "INVERTED" ]; then
	es_customsargs="es.customsargs=--screensize "$H_RES_EDID" "$V_RES_EDID" --screenoffset 00 00"
	es_arg="--screensize "$H_RES_EDID" "$V_RES_EDID" --screenoffset 00 00"
else
	es_customsargs="es.customsargs=--screensize "$V_RES_EDID" "$H_RES_EDID" --screenoffset 00 00"
	es_arg="--screensize "$V_RES_EDID" "$H_RES_EDID" --screenoffset 00 00"
fi
echo $es_customsargs >> "$file_BatoceraConf"
cat >> "$file_BatoceraConf" <<'EOF'
###################################################
#	CRT CONFIG RETROARCH
###################################################
###################################################
#  RETROARCH MENU DRIVER — RGUI (recommended on CRTs)
#    • rgui  — classic, low-overhead, sharp at low resolutions
global.retroarch.menu_driver=rgui
###################################################
#  RETROARCH — SHOW ADVANCED SETTINGS (ENABLED)
#
#  What this does:
#    • Shows hidden expert pages in RetroArch’s menu.
global.retroarch.menu_show_advanced_settings=true
###################################################
#  RETROARCH — MENU WIDGETS (OSD POP-UPS) DISABLED
#  Disables toast-style UI elements to keep CRT runs lean and stable.
global.retroarch.menu_enable_widgets=false
###################################################
#  RETROARCH — CRT SWITCHRES VIA switchres.ini (MODE 4)
#  Delegates modeline decisions to SwitchRes using your switchres.ini.
global.retroarch.crt_switch_resolution=4
###################################################
EOF
if [ "$dotclock_min" == "25.0" ]; then
	echo "global.retroarch.crt_switch_resolution_super=$super_width" >> "$file_BatoceraConf"
else echo "global.retroarch.crt_switch_resolution_super=0" >> "$file_BatoceraConf"; fi
cat >> "$file_BatoceraConf" <<EOF
###################################################
#  RETROARCH — CRT HI-RES MENU (ENABLED)
#  Use a higher-resolution mode for the RA menu; games stay native.
global.retroarch.crt_switch_hires_menu=true
###################################################
#  RETROARCH DESKTOP MENU (Qt) — DISABLED
#  Disable RetroArch's built-in Qt desktop menu interface (WIMP UI).
#  Even when you don't use the Qt UI, RetroArch still initializes it by default,
#  which can:
#    • add extra CPU overhead and memory usage,
#    • introduce thread contention,
#    • can cause subtle frame or audio timing issues (especially under Xorg).
#  The setting below disables the Qt desktop UI entirely.
global.retroarch.desktop_menu_enable=false
###################################################
#  DISABLE DEFAULT SHADER, BILINEAR FILTERING & VRR
#  Keep pixels sharp and timing stable for native CRT modes.
global.shaderset=none
global.smooth=0
global.retroarch.vrr_runloop_enable=0
###################################################
#  DISABLE / QUIET RETROARCH NOTIFICATIONS
###################################################
##  Hide refresh-rate change notification
global.retroarch.notification_show_refresh_rate=false
##  Smaller on-screen text for CRTs (default 32 is huge at 240p)
global.retroarch.video_font_size = 10
##  (Optional) Hide the 'Onscreen Display' submenu from RetroArch
global.retroarch.settings_show_onscreen_display=false
###################################################
# ---------- RetroArch — Per-event Notification Toggles ----------
# These options control specific pop-up toasts.
# feedback; change to "false" to quiet that specific message.
## RetroArch per-event notifications — set to "false" to hide a given toast
# Shows a toast when a gamepad autoconfig profile is applied (driver/name)
global.retroarch.notification_show_autoconfig=true
# Shows a toast when cheats are (re)applied to the running content
global.retroarch.notification_show_cheats_applied=true
# Shows a toast when a config override (core/game/dir) is loaded
global.retroarch.notification_show_config_override_load=true
# Shows a toast when fast-forward is toggled (and often the speed)
global.retroarch.notification_show_fast_forward=true
# Shows extra netplay info toasts (join/leave, status, misc events)
global.retroarch.notification_show_netplay_extra=true
# Shows a toast when a ROM patch (IPS/UPS/BPS, etc.) is applied
global.retroarch.notification_show_patch_applied=true
# Shows a toast when an input remap file is loaded
global.retroarch.notification_show_remap_load=true
# Shows a toast when a screenshot is captured (usually with save path)
global.retroarch.notification_show_screenshot=true
# Shows a toast when the initial disk is set for multi-disk content
global.retroarch.notification_show_set_initial_disk=true
###################################################
##  GUNCON2 SHADER SAVE FIX
##  Ensures RetroArch actually uses shaders and saves presets as references,
##  so your GunCon2-related shader presets
##  persist across cores/games and aren’t lost on restart.
###################################################
# Save shader presets as *reference* files instead of flattening/embedding.
# This helps keep per-core/per-game presets (like GunCon2 effects) consistent
# and prevents accidental overwrites when RA regenerates configs.
global.retroarch.video_shader_preset_save_reference_enable=true
# Make sure the shader pipeline is actually enabled globally, so the saved
# presets load and apply (some setups disable shaders by default).
global.retroarch.video_shader_enable=true
###################################################
##  GLOBAL EMULATOR SETTINGS
###################################################
# Disable Batocera’s bezel artwork system globally (no overlays/frames)
##  No bezel artwork (use full native game image)
global.bezel=none
# Prevent automatic resize of the “tattoo” area when bezels would adjust layout
# (keeps the gameplay viewport stable and pixel-accurate)
##  Don’t auto-resize the bezel/tattoo layout area
global.bezel.resize_tattoo=0
# Hide the bezel “tattoo” watermark/logo (system/game branding)
##  Hide bezel watermark/logo (tattoo)
global.bezel.tattoo=0
# Don’t stretch bezel graphics to fill the screen (avoid distortion)
##  Don’t stretch bezels to fill screen; preserve proportions
global.bezel_stretch=0
# Disable Batocera HUD overlays (e.g., FPS, temps) during gameplay
##  Disable Batocera HUD (FPS/temps overlays)
global.hud=none
EOF
term_rotation="display.rotate="
term_es_rotation=$term_rotation$((es_rotation_choice-1))
cat >> "$file_BatoceraConf" <<'EOF'
###################################################
#  EMULATIONSTATION UI ROTATION (MENU & THEME ONLY)
#  Sets the orientation of EmulationStation’s interface.
#  This does NOT rotate games; emulators are handled separately by the script.
#  ES ROTATION  MODE
EOF
echo $term_es_rotation >> "$file_BatoceraConf"; cd /usr/bin/mame; ./mame -cc
case $Version_of_batocera in
    v44)
		if [ ! -d "/userdata/system/configs/mame" ];then
			mkdir /userdata/system/configs/mame; mkdir /userdata/system/configs/mame/ini
		elif [ ! -d "/userdata/system/configs/mame/ini" ];then mkdir /userdata/system/configs/mame/ini; fi
		mv /usr/bin/mame/*.ini /userdata/system/configs/mame/
		sed -e "s/\[monitor-name\]/$monitor_name_MAME/g" -e "s/\[super_width_mame\]/$super_width_mame/g" -e "s/\[dotclock_min_mame\]/$dotclock_min_mame/g" \
			"$CRTD"//Mame_configs/mame.ini-switchres-generic-v36 > /userdata/system/configs/mame/mame.ini
		chmod 644 /userdata/system/configs/mame/mame.ini
		cp "$CRTD"/Mame_configs/ui.ini-switchres /userdata/system/configs/mame/ui.ini
		chmod 644 /userdata/system/configs/mame/ui.ini
 		cp "$CRTD"/GunCon2/gunlight/plugin.ini /userdata/system/configs/mame/plugin.ini
		chmod 644 /userdata/system/configs/mame/plugin.ini ;;
	*) echo "Problem of version" ;;
esac
cp /userdata/system/configs/mame/mame.ini /userdata/system/configs/mame/mame.ini.bak
if [ ! -d "/userdata/system//mame" ];then mkdir /userdata/system/mame; fi
cat >> "$file_BatoceraConf" <<'EOF'
###################################################
##  CRT SYSTEM SETTINGS
###################################################
CRT.emulator=sh
CRT.core=sh
###################################################
##  GROOVYMAME EMULATOR SETTINGS
###################################################
mame.bezel=none
mame.bezel_stretch=0
mame.core=mame
mame.emulator=mame
mame.bezel.tattoo=0
mame.bgfxshaders=None
mame.hud=none
mame.switchres=1
###################################################
##  NEOGEO SYSTEM SETTINGS
###################################################
neogeo.bezel=none
neogeo.bezel_stretch=0
neogeo.core=mame
neogeo.emulator=mame
neogeo.bezel.tattoo=0
neogeo.bgfxshaders=None
neogeo.hud=none
neogeo.switchres=1
###################################################
##  MAME EMULATOR SETTINGS
##  APPLE2 / CAMPUTER LYNX / ACORN BBC/ELECTRON/ARCHIMEDE
###################################################
apple2.core=mame
apple2.emulator=mame
apple2.switchres=1
bbc.core=mame
bbc.emulator=mame
bbc.switchres=1
electron.core=mame
electron.emulator=mame
electron.switchres=1
archimedes.core=mame
archimedes.emulator=mame
archimedes.switchres=1
camplynx.core=mame
camplynx.emulator=mame
camplynx.switchres=1
###################################################
##  STANDALONE EMULATOR SETTINGS
###################################################
amiga500.core=A500
amiga500.cpu_compatibility=exact
amiga500.emulator=fsuae
amiga500.video_allow_rotate=true
amigacd32.core=CD32
amigacd32.emulator=fsuae
atarist.core=hatari
atarist.emulator=hatari
dos.core=dosbox
dos.emulator=dosbox
msx1.core=openmsx
msx1.emulator=openmsx
msx2.core=openmsx
msx2.emulator=openmsx
msx2+.core=openmsx
flash.core=lightspark
flash.emulator=lightspark
msx2+.emulator=openmsx
###################################################
##  GROOVYMAME TATE SETTINGS
###################################################
EOF
if [ -d "/userdata/system/configs/mame/ini" ];then
	if [ -f "/userdata/system/configs/mame/ini/horizont.ini" ];then rm /userdata/system/configs/mame/ini/horizont.ini; fi
if [ -f "/userdata/system/configs/mame/ini/vertical.ini" ];then rm /userdata/system/configs/mame/ini/vertical.ini; fi
fi
tate_rot=(none autoror none autorol)
tate_tpl=(normal clockwise counter-clockwise inverted counter-clockwise clockwise inverted clockwise counter-clockwise normal clockwise counter-clockwise)
case $es_rotation_choice in 1|2|3|4)
	echo "mame.rotation=${tate_rot[es_rotation_choice-1]}" >> "$file_BatoceraConf"
	case $Rotating_screen in None) _tr=1 ;; Clockwise) _tr=2 ;; Counter-Clockwise) _tr=3 ;; *) _tr= ;; esac
	if [ -n "$_tr" ]; then
		if (( es_rotation_choice % 2 )); then _tk=vertical; else _tk=horizont; fi
		_sw=super_width_$_tk _il=interlace_$_tk _dc=dotclock_min_$_tk
		sed -e "s/\[$_sw\]/${!_sw}/g" -e "s/\[$_il\]/${!_il}/g" -e "s/\[$_dc\]/${!_dc}/g" \
			"${CRTD}/Mame_configs/Mame_TATE/${_tk}_${tate_tpl[3*(es_rotation_choice-1)+_tr-1]}.ini" > "/userdata/system/configs/mame/ini/$_tk.ini"
	else echo "Problems of rotation_choice"; fi
	append_fbneo_tate_settings ;;
esac
