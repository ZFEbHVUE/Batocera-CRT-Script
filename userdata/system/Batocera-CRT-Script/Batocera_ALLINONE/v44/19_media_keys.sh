#######################################################################################
# Media keys + blind CRT to HD chord (Steam Deck): combo, watcher, userdata mirror,
# user service. combo.debug is never installed; remove it for full HD restore + shutdown.
#######################################################################################
cp /userdata/system/Batocera-CRT-Script/extra/media_keys/multimedia_keys.conf /userdata/system/configs/
cp /userdata/system/Batocera-CRT-Script/extra/media_keys/esrestart /usr/bin
cp /userdata/system/Batocera-CRT-Script/extra/media_keys/xrestart /usr/bin
cp /userdata/system/Batocera-CRT-Script/extra/media_keys/emukill /usr/bin
cp /userdata/system/Batocera-CRT-Script/extra/media_keys/crt-mode-switch-combo /tmp/crt-mode-switch-combo.install
chmod 755 /tmp/crt-mode-switch-combo.install
# Older bad deploys may have created /usr/bin/crt-mode-switch-combo as a directory; replace with file.
rm -rf /usr/bin/crt-mode-switch-combo
mv /tmp/crt-mode-switch-combo.install /usr/bin/crt-mode-switch-combo
chmod 755 /usr/bin/crt-mode-switch-combo
cp /userdata/system/Batocera-CRT-Script/extra/media_keys/crt-mode-switch-watcher.py /usr/bin
chmod 644 /userdata/system/configs/multimedia_keys.conf
chmod 755 /usr/bin/esrestart
chmod 755 /usr/bin/xrestart
chmod 755 /usr/bin/emukill
chmod 755 /usr/bin/crt-mode-switch-combo
chmod 755 /usr/bin/crt-mode-switch-watcher.py
# Mirror into userdata (survives reboot without batocera-save-overlay; read-only /usr may reset).
UD_MEDIA_KEYS="/userdata/system/Batocera-CRT-Script/extra/media_keys"
mkdir -p "$UD_MEDIA_KEYS"
cp -f /usr/bin/crt-mode-switch-combo "$UD_MEDIA_KEYS/crt-mode-switch-combo"
cp -f /usr/bin/crt-mode-switch-watcher.py "$UD_MEDIA_KEYS/crt-mode-switch-watcher.py"
chmod 755 "$UD_MEDIA_KEYS/crt-mode-switch-combo" "$UD_MEDIA_KEYS/crt-mode-switch-watcher.py"
mkdir -p /userdata/system/services
# Service prefers userdata watcher/combo paths (no overlay required to update them).
cp /userdata/system/Batocera-CRT-Script/extra/media_keys/crt_mode_switch_watcher /userdata/system/services/crt_mode_switch_watcher
chmod 755 /userdata/system/services/crt_mode_switch_watcher
# Watcher is OFF by default; enable via HD/CRT Mode Switcher (Blind Switch Watcher) or:
#   batocera-services enable crt_mode_switch_watcher && batocera-services start crt_mode_switch_watcher

