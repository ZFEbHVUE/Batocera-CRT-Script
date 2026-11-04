
#######################################################################################
## Bootstrap videomode/videooutput — capture HD state and derive CRT Boot_ mode
#######################################################################################
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

#######################################################################################
## how create a file /userdatat/system/es.arg.override
#######################################################################################
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

#######################################################################################
## how to center EmulationStation
#######################################################################################
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
	es_arg="--screensize "$H_RES_EDID" "$V_RES_EDID" --screenoffset 00 00"
else
	es_customsargs="es.customsargs=--screensize "$V_RES_EDID" "$H_RES_EDID" --screenoffset 00 00"
	es_arg="--screensize "$V_RES_EDID" "$H_RES_EDID" --screenoffset 00 00"
fi
echo $es_customsargs 									>> "$file_BatoceraConf"

#######################################################################################"
## CRT GLOBAL CONFIG FOR RETROARCH
#######################################################################################"
echo "###################################################"                               >> "$file_BatoceraConf"
echo "#	CRT CONFIG RETROARCH"                                                            >> "$file_BatoceraConf"
echo "###################################################"                               >> "$file_BatoceraConf"
echo "###################################################"                               >> "$file_BatoceraConf"
echo "#  RETROARCH MENU DRIVER — RGUI (recommended on CRTs)"                             >> "$file_BatoceraConf"
echo "#    • rgui  — classic, low-overhead, sharp at low resolutions"                    >> "$file_BatoceraConf"
echo "global.retroarch.menu_driver=rgui"                                                 >> "$file_BatoceraConf"
echo "###################################################"                               >> "$file_BatoceraConf"
echo "#  RETROARCH — SHOW ADVANCED SETTINGS (ENABLED)"                                   >> "$file_BatoceraConf"
echo "#"                                                                                 >> "$file_BatoceraConf"
echo "#  What this does:"                                                                >> "$file_BatoceraConf"
echo "#    • Shows hidden expert pages in RetroArch’s menu."                             >> "$file_BatoceraConf"
echo "global.retroarch.menu_show_advanced_settings=true"                                 >> "$file_BatoceraConf"
echo "###################################################"                               >> "$file_BatoceraConf"
echo "#  RETROARCH — MENU WIDGETS (OSD POP-UPS) DISABLED"                                >> "$file_BatoceraConf"
echo "#  Disables toast-style UI elements to keep CRT runs lean and stable."             >> "$file_BatoceraConf"
echo "global.retroarch.menu_enable_widgets=false"                                        >> "$file_BatoceraConf"
echo "###################################################"                               >> "$file_BatoceraConf"
echo "#  RETROARCH — CRT SWITCHRES VIA switchres.ini (MODE 4)"                           >> "$file_BatoceraConf"
echo "#  Delegates modeline decisions to SwitchRes using your switchres.ini."            >> "$file_BatoceraConf"
echo "global.retroarch.crt_switch_resolution=4"                                         >> "$file_BatoceraConf"
echo "###################################################"                               >> "$file_BatoceraConf"
if [ "$dotclock_min" == "25.0" ]; then
	echo "global.retroarch.crt_switch_resolution_super=$super_width"                     >> "$file_BatoceraConf"
else
	echo "global.retroarch.crt_switch_resolution_super=0"                                >> "$file_BatoceraConf"
fi
echo "###################################################"                               >> "$file_BatoceraConf"
echo "#  RETROARCH — CRT HI-RES MENU (ENABLED)"                                          >> "$file_BatoceraConf"
echo "#  Use a higher-resolution mode for the RA menu; games stay native."               >> "$file_BatoceraConf"
echo "global.retroarch.crt_switch_hires_menu=true"                                      >> "$file_BatoceraConf"
echo "###################################################"                               >> "$file_BatoceraConf"
echo "#  RETROARCH DESKTOP MENU (Qt) — DISABLED"                                         >> "$file_BatoceraConf"
echo "#  Disable RetroArch's built-in Qt desktop menu interface (WIMP UI)."              >> "$file_BatoceraConf"
echo "#  Even when you don't use the Qt UI, RetroArch still initializes it by default,"  >> "$file_BatoceraConf"
echo "#  which can:"                                                                     >> "$file_BatoceraConf"
echo "#    • add extra CPU overhead and memory usage,"                                   >> "$file_BatoceraConf"
echo "#    • introduce thread contention,"                                               >> "$file_BatoceraConf"
echo "#    • can cause subtle frame or audio timing issues (especially under Xorg)."     >> "$file_BatoceraConf"
echo "#  The setting below disables the Qt desktop UI entirely."                         >> "$file_BatoceraConf"
echo "global.retroarch.desktop_menu_enable=false"                                       >> "$file_BatoceraConf"
echo "###################################################"                               >> "$file_BatoceraConf"
echo "#  DISABLE DEFAULT SHADER, BILINEAR FILTERING & VRR"                               >> "$file_BatoceraConf"
echo "#  Keep pixels sharp and timing stable for native CRT modes."                      >> "$file_BatoceraConf"
echo "global.shaderset=none"                                                             >> "$file_BatoceraConf"
echo "global.smooth=0"                                                                   >> "$file_BatoceraConf"
echo "global.retroarch.vrr_runloop_enable=0"                                             >> "$file_BatoceraConf"
echo "###################################################"                               >> "$file_BatoceraConf"
echo "#  DISABLE / QUIET RETROARCH NOTIFICATIONS"                                        >> "$file_BatoceraConf"
echo "###################################################"                               >> "$file_BatoceraConf"
echo "##  Hide refresh-rate change notification"                                         >> "$file_BatoceraConf"
echo "global.retroarch.notification_show_refresh_rate=false"                            >> "$file_BatoceraConf"
echo "##  Smaller on-screen text for CRTs (default 32 is huge at 240p)"                  >> "$file_BatoceraConf"
echo "global.retroarch.video_font_size = 10" 						                     >> "$file_BatoceraConf"
echo "##  (Optional) Hide the 'Onscreen Display' submenu from RetroArch"                 >> "$file_BatoceraConf"
echo "global.retroarch.settings_show_onscreen_display=false"                            >> "$file_BatoceraConf"
echo "###################################################"                               >> "$file_BatoceraConf"
echo "# ---------- RetroArch — Per-event Notification Toggles ----------"                >> "$file_BatoceraConf"
echo "# These options control specific pop-up toasts."                                   >> "$file_BatoceraConf"
echo "# feedback; change to \"false\" to quiet that specific message."                   >> "$file_BatoceraConf"
echo "## RetroArch per-event notifications — set to \"false\" to hide a given toast"     >> "$file_BatoceraConf"
echo "# Shows a toast when a gamepad autoconfig profile is applied (driver/name)"        >> "$file_BatoceraConf"
echo "global.retroarch.notification_show_autoconfig=true"                               >> "$file_BatoceraConf"
echo "# Shows a toast when cheats are (re)applied to the running content"                >> "$file_BatoceraConf"
echo "global.retroarch.notification_show_cheats_applied=true"                           >> "$file_BatoceraConf"
echo "# Shows a toast when a config override (core/game/dir) is loaded"                  >> "$file_BatoceraConf"
echo "global.retroarch.notification_show_config_override_load=true"                     >> "$file_BatoceraConf"
echo "# Shows a toast when fast-forward is toggled (and often the speed)"                >> "$file_BatoceraConf"
echo "global.retroarch.notification_show_fast_forward=true"                             >> "$file_BatoceraConf"
echo "# Shows extra netplay info toasts (join/leave, status, misc events)"               >> "$file_BatoceraConf"
echo "global.retroarch.notification_show_netplay_extra=true"                            >> "$file_BatoceraConf"
echo "# Shows a toast when a ROM patch (IPS/UPS/BPS, etc.) is applied"                   >> "$file_BatoceraConf"
echo "global.retroarch.notification_show_patch_applied=true"                            >> "$file_BatoceraConf"
echo "# Shows a toast when an input remap file is loaded"                                >> "$file_BatoceraConf"
echo "global.retroarch.notification_show_remap_load=true"                               >> "$file_BatoceraConf"
echo "# Shows a toast when a screenshot is captured (usually with save path)"            >> "$file_BatoceraConf"
echo "global.retroarch.notification_show_screenshot=true"                               >> "$file_BatoceraConf"
echo "# Shows a toast when the initial disk is set for multi-disk content"               >> "$file_BatoceraConf"
echo "global.retroarch.notification_show_set_initial_disk=true"                         >> "$file_BatoceraConf"
echo "###################################################"                               >> "$file_BatoceraConf"
echo "##  GUNCON2 SHADER SAVE FIX"                                                       >> "$file_BatoceraConf"
echo "##  Ensures RetroArch actually uses shaders and saves presets as references,"      >> "$file_BatoceraConf"
echo "##  so your GunCon2-related shader presets"                                        >> "$file_BatoceraConf"
echo "##  persist across cores/games and aren’t lost on restart."                        >> "$file_BatoceraConf"
echo "###################################################"                               >> "$file_BatoceraConf"
echo "# Save shader presets as *reference* files instead of flattening/embedding."       >> "$file_BatoceraConf"
echo "# This helps keep per-core/per-game presets (like GunCon2 effects) consistent"     >> "$file_BatoceraConf"
echo "# and prevents accidental overwrites when RA regenerates configs."                 >> "$file_BatoceraConf"
echo "global.retroarch.video_shader_preset_save_reference_enable=true"                  >> "$file_BatoceraConf"
echo "# Make sure the shader pipeline is actually enabled globally, so the saved"        >> "$file_BatoceraConf"
echo "# presets load and apply (some setups disable shaders by default)."                >> "$file_BatoceraConf"
echo "global.retroarch.video_shader_enable=true"                                        >> "$file_BatoceraConf"
echo "###################################################"                               >> "$file_BatoceraConf"
echo "##  GLOBAL EMULATOR SETTINGS"                                                      >> "$file_BatoceraConf"
echo "###################################################"                               >> "$file_BatoceraConf"
echo "# Disable Batocera’s bezel artwork system globally (no overlays/frames)"           >> "$file_BatoceraConf"
echo "##  No bezel artwork (use full native game image)"                                 >> "$file_BatoceraConf"
echo "global.bezel=none"                                                                 >> "$file_BatoceraConf"
echo "# Prevent automatic resize of the “tattoo” area when bezels would adjust layout"   >> "$file_BatoceraConf"
echo "# (keeps the gameplay viewport stable and pixel-accurate)"                         >> "$file_BatoceraConf"
echo "##  Don’t auto-resize the bezel/tattoo layout area"                                >> "$file_BatoceraConf"
echo "global.bezel.resize_tattoo=0"                                                      >> "$file_BatoceraConf"
echo "# Hide the bezel “tattoo” watermark/logo (system/game branding)"                   >> "$file_BatoceraConf"
echo "##  Hide bezel watermark/logo (tattoo)"                                            >> "$file_BatoceraConf"
echo "global.bezel.tattoo=0"                                                             >> "$file_BatoceraConf"
echo "# Don’t stretch bezel graphics to fill the screen (avoid distortion)"              >> "$file_BatoceraConf"
echo "##  Don’t stretch bezels to fill screen; preserve proportions"                     >> "$file_BatoceraConf"
echo "global.bezel_stretch=0"                                                            >> "$file_BatoceraConf"
echo "# Disable Batocera HUD overlays (e.g., FPS, temps) during gameplay"                >> "$file_BatoceraConf"
echo "##  Disable Batocera HUD (FPS/temps overlays)"                                     >> "$file_BatoceraConf"
echo "global.hud=none"                                                                   >> "$file_BatoceraConf"
#######################################################################################
##  Rotation of EmulationStation
#######################################################################################

term_rotation="display.rotate="
term_es_rotation=$term_rotation$((es_rotation_choice-1))
echo "###################################################"                               >> "$file_BatoceraConf"
echo "#  EMULATIONSTATION UI ROTATION (MENU & THEME ONLY)"                               >> "$file_BatoceraConf"
echo "#  Sets the orientation of EmulationStation’s interface."                          >> "$file_BatoceraConf"
echo "#  This does NOT rotate games; emulators are handled separately by the script."    >> "$file_BatoceraConf"
echo "#  ES ROTATION  MODE" 								                             >> "$file_BatoceraConf"
echo $term_es_rotation									                                 >> "$file_BatoceraConf"

#######################################################################################
## Mame initialisation Batocera not for RetroLX at this time
#######################################################################################

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

#######################################################################################
## UPGRADE Mame  Batocera  create an folder for new binary of MAME (GroovyMame)
####################################################################################### 
if [ ! -d "/userdata/system//mame" ];then
	mkdir /userdata/system/mame
fi

####################################################################################### 
echo "###################################################"				>> "$file_BatoceraConf"
echo "##  CRT SYSTEM SETTINGS" 								            >> "$file_BatoceraConf"
echo "###################################################" 				>> "$file_BatoceraConf"
echo "CRT.emulator=sh" 									                >> "$file_BatoceraConf"
echo "CRT.core=sh" 									                    >> "$file_BatoceraConf"
echo "###################################################" 				>> "$file_BatoceraConf"
echo "##  GROOVYMAME EMULATOR SETTINGS" 						        >> "$file_BatoceraConf"
echo "###################################################" 				>> "$file_BatoceraConf"
echo "mame.bezel=none" 									                >> "$file_BatoceraConf"
echo "mame.bezel_stretch=0" 								            >> "$file_BatoceraConf"
echo "mame.core=mame" 									                >> "$file_BatoceraConf"
echo "mame.emulator=mame" 								                >> "$file_BatoceraConf"
echo "mame.bezel.tattoo=0" 								                >> "$file_BatoceraConf"
echo "mame.bgfxshaders=None" 								            >> "$file_BatoceraConf"
echo "mame.hud=none" 									                >> "$file_BatoceraConf"
echo "mame.switchres=1" 								                >> "$file_BatoceraConf"
echo "###################################################" 				>> "$file_BatoceraConf"
echo "##  NEOGEO SYSTEM SETTINGS" 							            >> "$file_BatoceraConf"
echo "###################################################" 				>> "$file_BatoceraConf"
echo "neogeo.bezel=none" 								                >> "$file_BatoceraConf"
echo "neogeo.bezel_stretch=0" 								            >> "$file_BatoceraConf"
echo "neogeo.core=mame" 								                >> "$file_BatoceraConf"
echo "neogeo.emulator=mame" 							                >> "$file_BatoceraConf"
echo "neogeo.bezel.tattoo=0" 								            >> "$file_BatoceraConf"
echo "neogeo.bgfxshaders=None" 								            >> "$file_BatoceraConf"
echo "neogeo.hud=none"									                >> "$file_BatoceraConf"
echo "neogeo.switchres=1" 								                >> "$file_BatoceraConf"
echo "###################################################" 				>> "$file_BatoceraConf"
echo "##  MAME EMULATOR SETTINGS" 							            >> "$file_BatoceraConf"
echo "##  APPLE2 / CAMPUTER LYNX / ACORN BBC/ELECTRON/ARCHIMEDE" 	    >> "$file_BatoceraConf"
echo "###################################################" 				>> "$file_BatoceraConf"
echo "apple2.core=mame" 								                >> "$file_BatoceraConf"
echo "apple2.emulator=mame" 							                >> "$file_BatoceraConf"
echo "apple2.switchres=1" 								                >> "$file_BatoceraConf"
echo "bbc.core=mame" 									                >> "$file_BatoceraConf"
echo "bbc.emulator=mame" 								                >> "$file_BatoceraConf"
echo "bbc.switchres=1" 									                >> "$file_BatoceraConf"
echo "electron.core=mame" 								                >> "$file_BatoceraConf"
echo "electron.emulator=mame" 								            >> "$file_BatoceraConf"
echo "electron.switchres=1" 								            >> "$file_BatoceraConf"
echo "archimedes.core=mame" 								            >> "$file_BatoceraConf"
echo "archimedes.emulator=mame" 							            >> "$file_BatoceraConf"
echo "archimedes.switchres=1" 								            >> "$file_BatoceraConf"
echo "camplynx.core=mame"								                >> "$file_BatoceraConf"
echo "camplynx.emulator=mame"								            >> "$file_BatoceraConf"
echo "camplynx.switchres=1" 								            >> "$file_BatoceraConf"
echo "###################################################" 				>> "$file_BatoceraConf"
echo "##  STANDALONE EMULATOR SETTINGS" 						        >> "$file_BatoceraConf"
echo "###################################################" 				>> "$file_BatoceraConf"
echo "amiga500.core=A500" 								                >> "$file_BatoceraConf"
echo "amiga500.cpu_compatibility=exact" 				                >> "$file_BatoceraConf"
echo "amiga500.emulator=fsuae" 							                >> "$file_BatoceraConf"
echo "amiga500.video_allow_rotate=true" 				                >> "$file_BatoceraConf"
echo "amigacd32.core=CD32" 								                >> "$file_BatoceraConf"
echo "amigacd32.emulator=fsuae" 						                >> "$file_BatoceraConf"
echo "atarist.core=hatari" 								                >> "$file_BatoceraConf"
echo "atarist.emulator=hatari" 							                >> "$file_BatoceraConf"
echo "dos.core=dosbox" 									                >> "$file_BatoceraConf"
echo "dos.emulator=dosbox" 								                >> "$file_BatoceraConf"
echo "msx1.core=openmsx" 								                >> "$file_BatoceraConf"
echo "msx1.emulator=openmsx" 							                >> "$file_BatoceraConf"
echo "msx2.core=openmsx" 								                >> "$file_BatoceraConf"
echo "msx2.emulator=openmsx"							                >> "$file_BatoceraConf"
echo "msx2+.core=openmsx" 								                >> "$file_BatoceraConf"
echo "flash.core=lightspark" 							                >> "$file_BatoceraConf"
echo "flash.emulator=lightspark" 						                >> "$file_BatoceraConf"
echo "msx2+.emulator=openmsx" 							                >> "$file_BatoceraConf"
echo "###################################################" 				>> "$file_BatoceraConf"
echo "##  GROOVYMAME TATE SETTINGS" 							        >> "$file_BatoceraConf"
echo "###################################################" 				>> "$file_BatoceraConf"
 
if [ -d "/userdata/system/configs/mame/ini" ];then
	if [ -f "/userdata/system/configs/mame/ini/horizont.ini" ];then
		rm /userdata/system/configs/mame/ini/horizont.ini
	fi
if [ -f "/userdata/system/configs/mame/ini/vertical.ini" ];then
		rm /userdata/system/configs/mame/ini/vertical.ini
	fi
fi

if [ $es_rotation_choice -eq 1 ]; then
	echo "mame.rotation=none" 							>> "$file_BatoceraConf"
	case $Rotating_screen in 
		None)
			sed -e "s/\[super_width_vertical\]/$super_width_vertical/g" -e "s/\[interlace_vertical\]/$interlace_vertical/g" -e "s/\[dotclock_min_vertical\]/$dotclock_min_vertical/g" \
				/userdata/system/Batocera-CRT-Script/Mame_configs/Mame_TATE/vertical_normal.ini > /userdata/system/configs/mame/ini/vertical.ini
		;;
		Clockwise)
			sed -e "s/\[super_width_vertical\]/$super_width_vertical/g" -e "s/\[interlace_vertical\]/$interlace_vertical/g" -e "s/\[dotclock_min_vertical\]/$dotclock_min_vertical/g" \
				  /userdata/system/Batocera-CRT-Script/Mame_configs/Mame_TATE/vertical_clockwise.ini > /userdata/system/configs/mame/ini/vertical.ini
		;;
		Counter-Clockwise)
			sed -e "s/\[super_width_vertical\]/$super_width_vertical/g" -e "s/\[interlace_vertical\]/$interlace_vertical/g" -e "s/\[dotclock_min_vertical\]/$dotclock_min_vertical/g" \
				 /userdata/system/Batocera-CRT-Script/Mame_configs/Mame_TATE/vertical_counter-clockwise.ini > /userdata/system/configs/mame/ini/vertical.ini
		;;
		*)
			echo "Problems of rotation_choice"
		;;
	esac
	append_fbneo_tate_settings
fi

if [ $es_rotation_choice -eq 2 ]; then
	echo "mame.rotation=autoror"							>> "$file_BatoceraConf"
	case $Rotating_screen in 
		None)	
			sed -e "s/\[super_width_horizont\]/$super_width_horizont/g" -e "s/\[interlace_horizont\]/$interlace_horizont/g" -e "s/\[dotclock_min_horizont\]/$dotclock_min_horizont/g" \
					/userdata/system/Batocera-CRT-Script/Mame_configs/Mame_TATE/horizont_inverted.ini > /userdata/system/configs/mame/ini/horizont.ini
		;;
		Clockwise)
			sed -e "s/\[super_width_horizont\]/$super_width_horizont/g" -e "s/\[interlace_horizont\]/$interlace_horizont/g" -e "s/\[dotclock_min_horizont\]/$dotclock_min_horizont/g" \
					/userdata/system/Batocera-CRT-Script/Mame_configs/Mame_TATE/horizont_counter-clockwise.ini > /userdata/system/configs/mame/ini/horizont.ini
		;;
		Counter-Clockwise)
			sed -e "s/\[super_width_horizont\]/$super_width_horizont/g" -e "s/\[interlace_horizont\]/$interlace_horizont/g" -e "s/\[dotclock_min_horizont\]/$dotclock_min_horizont/g" \
					/userdata/system/Batocera-CRT-Script/Mame_configs/Mame_TATE/horizont_clockwise.ini > /userdata/system/configs/mame/ini/horizont.ini
		;;
		*)
			echo "Problems of rotation_choice"
		;;
	esac
	append_fbneo_tate_settings
fi

if [ $es_rotation_choice -eq 3 ]; then
	echo "mame.rotation=none" 							>> "$file_BatoceraConf"
	case $Rotating_screen in 
		None)
			sed -e "s/\[super_width_vertical\]/$super_width_vertical/g" -e "s/\[interlace_vertical\]/$interlace_vertical/g" -e "s/\[dotclock_min_vertical\]/$dotclock_min_vertical/g" \
				/userdata/system/Batocera-CRT-Script/Mame_configs/Mame_TATE/vertical_inverted.ini > /userdata/system/configs/mame/ini/vertical.ini
		;;
		Clockwise)
			sed -e "s/\[super_width_vertical\]/$super_width_vertical/g" -e "s/\[interlace_vertical\]/$interlace_vertical/g" -e "s/\[dotclock_min_vertical\]/$dotclock_min_vertical/g" \
				/userdata/system/Batocera-CRT-Script/Mame_configs/Mame_TATE/vertical_clockwise.ini > /userdata/system/configs/mame/ini/vertical.ini
		;;
		Counter-Clockwise)
			sed -e "s/\[super_width_vertical\]/$super_width_vertical/g" -e "s/\[interlace_vertical\]/$interlace_vertical/g" -e "s/\[dotclock_min_vertical\]/$dotclock_min_vertical/g" \
				/userdata/system/Batocera-CRT-Script/Mame_configs/Mame_TATE/vertical_counter-clockwise.ini > /userdata/system/configs/mame/ini/vertical.ini      
		;;
		*)
			echo "Problems of rotation_choice"
		;;
	esac
	append_fbneo_tate_settings
fi

if [ $es_rotation_choice -eq 4 ]; then
	echo "mame.rotation=autorol"							>> "$file_BatoceraConf"
	case $Rotating_screen in 
		None)
			sed -e "s/\[super_width_horizont\]/$super_width_horizont/g" -e "s/\[interlace_horizont\]/$interlace_horizont/g" -e "s/\[dotclock_min_horizont\]/$dotclock_min_horizont/g" \
				/userdata/system/Batocera-CRT-Script/Mame_configs/Mame_TATE/horizont_normal.ini > /userdata/system/configs/mame/ini/horizont.ini
		;;
		Clockwise)
			sed -e "s/\[super_width_horizont\]/$super_width_horizont/g" -e "s/\[interlace_horizont\]/$interlace_horizont/g" -e "s/\[dotclock_min_horizont\]/$dotclock_min_horizont/g" \
				/userdata/system/Batocera-CRT-Script/Mame_configs/Mame_TATE/horizont_clockwise.ini > /userdata/system/configs/mame/ini/horizont.ini
		;;
		Counter-Clockwise)
			sed -e "s/\[super_width_horizont\]/$super_width_horizont/g" -e "s/\[interlace_horizont\]/$interlace_horizont/g" -e "s/\[dotclock_min_horizont\]/$dotclock_min_horizont/g" \
				/userdata/system/Batocera-CRT-Script/Mame_configs/Mame_TATE/horizont_counter-clockwise.ini > /userdata/system/configs/mame/ini/horizont.ini
			;;
			*)
				echo "Problems of rotation_choice"
			;;
		esac
	append_fbneo_tate_settings
fi
chmod 755 "$file_BatoceraConf"
