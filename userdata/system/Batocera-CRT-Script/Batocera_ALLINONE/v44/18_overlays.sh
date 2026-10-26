#######################################################################################
# Add Overlays and Overrides for handheld system Tool
#######################################################################################
cp /userdata/system/Batocera-CRT-Script/extra/overlays_overrides.sh "$CRT_ROMS/crt"
cp /userdata/system/Batocera-CRT-Script/extra/overlays_overrides.sh.keys "$CRT_ROMS/crt"
chmod 755 "$CRT_ROMS/crt/overlays_overrides.sh"
chmod 644 "$CRT_ROMS/crt/overlays_overrides.sh.keys"
chmod 755 /userdata/system/Batocera-CRT-Script/extra/overlays_overrides_script.sh

