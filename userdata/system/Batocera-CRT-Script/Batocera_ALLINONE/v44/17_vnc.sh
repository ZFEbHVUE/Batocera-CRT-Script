#######################################################################################
# Add VNC server files to /lib & /usr/lib for v41
#######################################################################################
#mv /lib/libcrypt.so.1 /lib/libcrypt.so.1.bak
cp /userdata/system/Batocera-CRT-Script/install-vnc_server_batocera/libcrypt.so.1 /lib/libcrypt.so.1 
cp /userdata/system/Batocera-CRT-Script/install-vnc_server_batocera/libcrypt.so.1 /usr/lib/libcrypt.so.1
cp /userdata/system/Batocera-CRT-Script/install-vnc_server_batocera/libvncclient.so.1 /usr/lib/libvncclient.so.1
cp /userdata/system/Batocera-CRT-Script/install-vnc_server_batocera/libvncserver.so.1 /usr/lib/libvncserver.so.1
cp /userdata/system/Batocera-CRT-Script/install-vnc_server_batocera/libsasl2.so.2 /usr/lib/libsasl2.so.2
cp /userdata/system/Batocera-CRT-Script/install-vnc_server_batocera/vnc /usr/bin/vnc
cp /userdata/system/Batocera-CRT-Script/install-vnc_server_batocera/x11vnc /usr/bin/x11vnc
cp /userdata/system/Batocera-CRT-Script/install-vnc_server_batocera/vnc-scaled /usr/bin/vnc-scaled

chmod 0755 /lib/libcrypt.so.1
chmod 0644 /usr/lib/libcrypt.so.1
chmod 0644 /usr/lib/libvncclient.so.1
chmod 0644 /usr/lib/libvncserver.so.1
chmod 0644 /usr/lib/libsasl2.so.2
chmod +x /usr/bin/vnc
chmod +x /usr/bin/x11vnc
chmod +x /usr/bin/vnc-scaled

