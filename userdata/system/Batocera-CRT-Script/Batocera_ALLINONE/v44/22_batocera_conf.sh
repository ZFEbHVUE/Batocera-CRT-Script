
# Bootstrap videomode and videooutput: capture the HD state and derive the CRT Boot_ mode.
MODE_BACKUP_BASE="/userdata/Batocera-CRT-Script-Backup/mode_backups"

# Step 1: Capture current HD values (batocera.conf still reflects HD state at this point)
_hd_videomode=$(batocera-settings-get global.videomode 2>/dev/null || true)
_hd_videooutput=$(batocera-settings-get global.videooutput 2>/dev/null || true)

# Step 2: Write HD backup files (mode switcher reads these on CRT->HD switch)
mkdir -p "${MODE_BACKUP_BASE}/hd_mode/video_settings"
# The HD list is saved when the system-restore backup is created.
# Do not capture again here. videomodes.conf is already the 15 kHz list.
if [ ! -s "${MODE_BACKUP_BASE}/hd_mode/video_settings/hd_mode_list.txt" ]; then
echo "global.videomode=${_hd_videomode:-default}" \
    > "${MODE_BACKUP_BASE}/hd_mode/video_settings/video_mode.txt"
fi
echo "${_hd_videooutput}" \
    > "${MODE_BACKUP_BASE}/hd_mode/video_settings/video_output.txt"

# Step 3: Derive CRT Boot_ mode from installed videomodes.conf
_crt_boot_line=$(grep "Boot_" /userdata/system/videomodes.conf 2>/dev/null \
    | grep "^${H_RES_EDID}x${V_RES_EDID}\." | head -1)
_crt_boot_mode="${_crt_boot_line%%:*}"

# /userdata/system/es.arg.override
file="/userdata/system/es.arg.override"

#screensize_x_new=$H_RES_EDID
#screensize_y_new=$V_RES_EDID
screensizeoffset_x_new=00
screensizeoffset_y_new=00
screenoffset_x_new=00
screenoffset_y_new=00

if [ -f "$file" ]; then
	rm $file
fi
touch $file
#echo "screensize_x $screensize_x_new" > "$file"
#echo "screensize_y $screensize_y_new" >> "$file"
echo "screensizeoffset_x $screensizeoffset_x_new" > "$file"
echo "screensizeoffset_y $screensizeoffset_y_new" >> "$file"
echo "screenoffset_x $screenoffset_x_new" >> "$file"
echo "screenoffset_y $screenoffset_y_new" >> "$file"
chmod 644 $file

# batocera.conf. One of the lines tells the user how to center EmulationStation.
file_BatoceraConf="/userdata/system/batocera.conf"

append_crt_script_settings_start() {
	{
		echo "###################################################"
		echo "## CRT Script Settings Start"
		echo "###################################################"
		echo "## ES Settings, See wiki page on how to center EmulationStation"
	} >> "$file_BatoceraConf"
}

append_fbneo_tate_settings() {
	{
		echo "###################################################"
		echo "##  FBNEO CORE TATE SETTINGS"
		echo "###################################################"
		echo "fbneo.video_allow_rotate=off"
		echo "###################################################"
		echo "## CRT Script Settings End"
		echo "###################################################"
	} >> "$file_BatoceraConf"
}


# Steps 4-5: Write CRT videomode/videooutput to batocera.conf and pre-populate CRT backup
# Remove any existing lines first to avoid duplicates (factory conf may have these set)
if [ -n "$_crt_boot_mode" ]; then
    sed -i '/^global\.videomode=/d' "$file_BatoceraConf"
    echo "global.videomode=$_crt_boot_mode"        >> "$file_BatoceraConf"
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

if [ "$BOOT_RESOLUTION_ES" == "1" ]; then
	echo $Resolution_es 								>> "$file_BatoceraConf"
fi
# Step 6: Fix es.resolution to use the correct videomodes.conf key.
# The installer writes es.resolution with a .00000 suffix which does not match any
# key in batocera-resolution listModes, causing ES to show "AUTO" in Video Mode.
# Replace with the exact key derived from videomodes.conf (e.g. 641x480.60.00059).
if [ -n "$_crt_boot_mode" ]; then
    sed -i '/^es\.resolution=/d' "$file_BatoceraConf"
    echo "es.resolution=$_crt_boot_mode" >> "$file_BatoceraConf"
fi
append_crt_script_settings_start

if [ "$ES_rotation" == "NORMAL" ] || [ "$ES_rotation" == "INVERTED" ]; then
	es_customsargs="es.customsargs=--screensize "$H_RES_EDID" "$V_RES_EDID" --screenoffset 00 00"
else
	es_customsargs="es.customsargs=--screensize "$V_RES_EDID" "$H_RES_EDID" --screenoffset 00 00"
fi
echo $es_customsargs 									>> "$file_BatoceraConf"

#######################################################################################"
## CRT GLOBAL CONFIG FOR RETROARCH
#######################################################################################"
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
	echo "global.retroarch.crt_switch_resolution_super=$super_width"                     >> "$file_BatoceraConf"
else
	echo "global.retroarch.crt_switch_resolution_super=0"                                >> "$file_BatoceraConf"
fi
cat >> "$file_BatoceraConf" <<'EOF'
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

# Rotation of EmulationStation
term_rotation="display.rotate="
term_es_rotation=$term_rotation$((es_rotation_choice-1))
cat >> "$file_BatoceraConf" <<'EOF'
###################################################
#  EMULATIONSTATION UI ROTATION (MENU & THEME ONLY)
#  Sets the orientation of EmulationStation’s interface.
#  This does NOT rotate games; emulators are handled separately by the script.
#  ES ROTATION  MODE
EOF
echo $term_es_rotation									                                 >> "$file_BatoceraConf"

# v44 MAME ini, ui.ini, and the GunCon2 plugin.ini.

cd /usr/bin/mame
./mame -cc
case $Version_of_batocera in
    v44)
		if [ ! -d "/userdata/system/configs/mame" ];then
			mkdir /userdata/system/configs/mame
			mkdir /userdata/system/configs/mame/ini
		elif [ ! -d "/userdata/system/configs/mame/ini" ];then
			mkdir /userdata/system/configs/mame/ini
		fi
		mv /usr/bin/mame/*.ini /userdata/system/configs/mame/
		sed -e "s/\[monitor-name\]/$monitor_name_MAME/g" -e "s/\[super_width_mame\]/$super_width_mame/g" -e "s/\[dotclock_min_mame\]/$dotclock_min_mame/g" \
			/userdata/system/Batocera-CRT-Script//Mame_configs/mame.ini-switchres-generic-v36 > /userdata/system/configs/mame/mame.ini
		chmod 644 /userdata/system/configs/mame/mame.ini
		cp /userdata/system/Batocera-CRT-Script/Mame_configs/ui.ini-switchres /userdata/system/configs/mame/ui.ini
		chmod 644 /userdata/system/configs/mame/ui.ini

 		cp /userdata/system/Batocera-CRT-Script/GunCon2/gunlight/plugin.ini /userdata/system/configs/mame/plugin.ini
		chmod 644 /userdata/system/configs/mame/plugin.ini
	;;


	*)
		echo "Problem of version"
	;;
esac

cp /userdata/system/configs/mame/mame.ini       /userdata/system/configs/mame/mame.ini.bak 

# Directory a GroovyMAME binary can be placed in. 
if [ ! -d "/userdata/system//mame" ];then
	mkdir /userdata/system/mame
fi

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
	if [ -f "/userdata/system/configs/mame/ini/horizont.ini" ];then
		rm /userdata/system/configs/mame/ini/horizont.ini
	fi
if [ -f "/userdata/system/configs/mame/ini/vertical.ini" ];then
		rm /userdata/system/configs/mame/ini/vertical.ini
	fi
fi

mame_rot=""
tate_kind=""
tate_src=""
case $es_rotation_choice in
	1)
		mame_rot="none"
		tate_kind="vertical"
		case $Rotating_screen in
			None) tate_src="vertical_normal.ini" ;;
			Clockwise) tate_src="vertical_clockwise.ini" ;;
			Counter-Clockwise) tate_src="vertical_counter-clockwise.ini" ;;
			*) echo "Problems of rotation_choice" ;;
		esac
		;;
	2)
		mame_rot="autoror"
		tate_kind="horizont"
		case $Rotating_screen in
			None) tate_src="horizont_inverted.ini" ;;
			Clockwise) tate_src="horizont_counter-clockwise.ini" ;;
			Counter-Clockwise) tate_src="horizont_clockwise.ini" ;;
			*) echo "Problems of rotation_choice" ;;
		esac
		;;
	3)
		mame_rot="none"
		tate_kind="vertical"
		case $Rotating_screen in
			None) tate_src="vertical_inverted.ini" ;;
			Clockwise) tate_src="vertical_clockwise.ini" ;;
			Counter-Clockwise) tate_src="vertical_counter-clockwise.ini" ;;
			*) echo "Problems of rotation_choice" ;;
		esac
		;;
	4)
		mame_rot="autorol"
		tate_kind="horizont"
		case $Rotating_screen in
			None) tate_src="horizont_normal.ini" ;;
			Clockwise) tate_src="horizont_clockwise.ini" ;;
			Counter-Clockwise) tate_src="horizont_counter-clockwise.ini" ;;
			*) echo "Problems of rotation_choice" ;;
		esac
		;;
esac
if [ -n "$mame_rot" ]; then
	echo "mame.rotation=$mame_rot" >> "$file_BatoceraConf"
	if [ -n "$tate_src" ]; then
		if [ "$tate_kind" = "vertical" ]; then
			sed -e "s/\[super_width_vertical\]/$super_width_vertical/g" -e "s/\[interlace_vertical\]/$interlace_vertical/g" -e "s/\[dotclock_min_vertical\]/$dotclock_min_vertical/g" \
				"/userdata/system/Batocera-CRT-Script/Mame_configs/Mame_TATE/$tate_src" > /userdata/system/configs/mame/ini/vertical.ini
		else
			sed -e "s/\[super_width_horizont\]/$super_width_horizont/g" -e "s/\[interlace_horizont\]/$interlace_horizont/g" -e "s/\[dotclock_min_horizont\]/$dotclock_min_horizont/g" \
				"/userdata/system/Batocera-CRT-Script/Mame_configs/Mame_TATE/$tate_src" > /userdata/system/configs/mame/ini/horizont.ini
		fi
	fi
	append_fbneo_tate_settings
fi
chmod 755 "$file_BatoceraConf"
