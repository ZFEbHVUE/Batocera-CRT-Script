#######################################################################################
# Create files for adjusting your CRT
#######################################################################################
# Pin CRT tools to internal drive to avoid mergerfs scattering to external drives
if [ -d "/userdata/.roms_base" ]; then
  CRT_ROMS="/userdata/.roms_base"
else
  CRT_ROMS="/userdata/roms"
fi
cp -a /userdata/system/Batocera-CRT-Script/Geometry_modeline/crt/ "$CRT_ROMS/"
cp /userdata/system/Batocera-CRT-Script/Geometry_modeline/es_systems_crt.cfg /userdata/system/configs/emulationstation/es_systems_crt.cfg
chmod 755 /userdata/system/Batocera-CRT-Script/Geometry_modeline/crt-launcher.sh
cp /userdata/system/Batocera-CRT-Script/Geometry_modeline/CRT.png /usr/share/emulationstation/themes/es-theme-carbon/art/consoles/CRT.png
cp /userdata/system/Batocera-CRT-Script/Geometry_modeline/CRT.svg /usr/share/emulationstation/themes/es-theme-carbon/art/logos/CRT.svg
chmod 755 "$CRT_ROMS/crt/es_adjust_tool.sh"
chmod 755 "$CRT_ROMS/crt/geometry.sh"
chmod 755 /userdata/system/Batocera-CRT-Script/Geometry_modeline/es_tool.sh
chmod 755 /userdata/system/Batocera-CRT-Script/Geometry_modeline/es_tool_legacy.sh
chmod 0644 /userdata/system/Batocera-CRT-Script/Geometry_modeline/es_tool.py
chmod 755 /userdata/system/Batocera-CRT-Script/Geometry_modeline/geometry.sh
chmod 0644 "$CRT_ROMS/crt/es_adjust_tool.sh.keys"
chmod 0644 "$CRT_ROMS/crt/geometry.sh.keys"
chmod 755 "$CRT_ROMS/crt/grid_tool.sh"
chmod 755 /userdata/system/Batocera-CRT-Script/Geometry_modeline/grid_tool.sh
chmod 0644 "$CRT_ROMS/crt/grid_tool.sh.keys"

