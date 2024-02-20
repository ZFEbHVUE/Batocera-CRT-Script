#!/bin/bash

# Batocera config file
install -D -m 0644 /userdata/system/batocera.conf /userdata/system/Batocera-CRT-Script/backup/userdata/system/batocera.conf

# Binary files
install -D -m 0755 /usr/bin/batocera-resolution /userdata/system/Batocera-CRT-Script/backup/usr/bin/batocera-resolution.backup
install -D -m 0755 /usr/bin/emulationstation-standalone /userdata/system/Batocera-CRT-Script/backup/usr/bin/emulationstation-standalone.backup
install -D -m 0755 /usr/bin/retroarch /userdata/system/Batocera-CRT-Script/backup/usr/bin/retroarch.backup

# Python scrips
install -D -m 0755 /usr/lib/python3.11/site-packages/configgen/emulatorlauncher.py /userdata/system/Batocera-CRT-Script/backup/usr/lib/python3.11/site-packages/configgen/emulatorlauncher.py.backup
install -D -m 0644 /usr/lib/python3.11/site-packages/configgen/utils/videoMode.py /userdata/system/Batocera-CRT-Script/backup/usr/lib/python3.11/site-packages/configgen/utils/videoMode.py.backup

# Boot Config
install -D -m 0755 /boot/batocera-boot.conf /userdata/system/Batocera-CRT-Script/backup/boot/batocera-boot.conf.backup

# syslinux
install -D -m 0755 /boot/boot/syslinux.cfg /userdata/system/Batocera-CRT-Script/backup/boot/boot/syslinux.cfg.backup
install -D -m 0755 /boot/boot/syslinux/syslinux.cfg /userdata/system/Batocera-CRT-Script/backup/boot/boot/syslinux/syslinux.cfg.backup
install -D -m 0755 /boot/EFI/syslinux.cfg /userdata/system/Batocera-CRT-Script/backup/boot/EFI/syslinux.cfg.backup
install -D -m 0755 /boot/EFI/batocera/syslinux.cfg /userdata/system/Batocera-CRT-Script/backup/boot/EFI/batocera/syslinux.cfg.backup
clear
exit