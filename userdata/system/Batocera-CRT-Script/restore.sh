#!/bin/bash
NONE='\033[00m'
RED='\033[01;31m'
GREEN='\033[01;32m'
YELLOW='\033[01;33m'
PURPLE='\033[01;35m'
CYAN='\033[01;36m'
WHITE='\033[01;37m'
BOLD='\033[1m'
UNDERLINE='\033[4m'
clear

echo "#######################################################################"
echo "##							             ##"
echo "##							             ##"
echo "##             This will restore files modified by the script 	     ##"
echo "##		        Press Enter to Continue 		     ##"
echo "##		        Exit with Pause/Break key  		     ##"
echo "##		        The system will reboot  		     ##"
echo "#######################################################################"
read
# Make boot writable
mount -o remount,rw /boot

# Batocera config file
install -D -m 0644 /userdata/system/BUILD_15KHz/backup/userdata/system/batocera.conf /userdata/system/batocera.conf

# Binary files
install -D -m 0755 /userdata/system/BUILD_15KHz/backup/usr/bin/batocera-resolution.backup /usr/bin/batocera-resolution
install -D -m 0755 /userdata/system/BUILD_15KHz/backup/usr/bin/emulationstation-standalone.backup /usr/bin/emulationstation-standalone
install -D -m 0755 /userdata/system/BUILD_15KHz/backup/usr/bin/retroarch.backup /usr/bin/retroarch

# Python scrips
install -D -m 0755 /userdata/system/BUILD_15KHz/backup/usr/lib/python3.11/site-packages/configgen/emulatorlauncher.py.backup /usr/lib/python3.11/site-packages/configgen/emulatorlauncher.py
install -D -m 0644 /userdata/system/BUILD_15KHz/backup/usr/lib/python3.11/site-packages/configgen/utils/videoMode.py.backup /usr/lib/python3.11/site-packages/configgen/utils/videoMode.py

# Boot Config
install -D -m 0755 /userdata/system/BUILD_15KHz/backup/boot/batocera-boot.conf.backup /boot/batocera-boot.conf

# syslinux
install -D -m 0755 /userdata/system/BUILD_15KHz/backup/boot/boot/syslinux.cfg.backup /boot/boot/syslinux.cfg
install -D -m 0755 /userdata/system/BUILD_15KHz/backup/boot/boot/syslinux/syslinux.cfg.backup /boot/boot/syslinux/syslinux.cfg
install -D -m 0755 /userdata/system/BUILD_15KHz/backup/boot/EFI/syslinux.cfg.backup /boot/EFI/syslinux.cfg
install -D -m 0755 /userdata/system/BUILD_15KHz/backup/boot/EFI/batocera/syslinux.cfg.backup /boot/EFI/batocera/syslinux.cfg

# 20-amdgpu.conf
install -D -m 644 /userdata/system/BUILD_15KHz/backup/etc/X11/xorg.conf.d/20-amdgpu.conf /etc/X11/xorg.conf.d/20-amdgpu.conf
	
# 20-radeon.conf
install -D -m 644 /userdata/system/BUILD_15KHz/backup/etc/X11/xorg.conf.d/20-radeon.conf /etc/X11/xorg.conf.d/20-radeon.conf 

# Delete scrips but backup them first just in case.
install -D -m 0755 /userdata/system/scripts/1_GunCon2.sh /userdata/system/BUILD_15KHz/backup/userdata/system/scripts/1_GunCon2.sh.backup
install -D -m 0755 /userdata/system/scripts/first_script.sh /userdata/system/BUILD_15KHz/backup/userdata/system/scripts/first_script.sh.backup
cp -ra /userdata/system/scripts/1_GunCon2.sh /userdata/system/BUILD_15KHz/backup/userdata/system/scripts/1_GunCon2.sh.backup-$(date +"%m-%d-%y-%T")
cp -ra /userdata/system/scripts/first_script.sh /userdata/system/BUILD_15KHz/backup/userdata/system/scripts/first_script.sh.backup-$(date +"%m-%d-%y-%T")
rm -r /userdata/system/scripts/
install -D -m 0644 /userdata/system/videomodes.conf /userdata/system/BUILD_15KHz/backup/userdata/system/videomodes.conf.backup
cp -ra /userdata/system/videomodes.conf /userdata/system/BUILD_15KHz/backup/userdata/system/videomodes.conf.backup-$(date +"%m-%d-%y-%T")
rm /userdata/system/videomodes.conf
rm /etc/X11/xorg.conf.d/10-monitor.conf

clear
batocera-save-overlay
reboot

