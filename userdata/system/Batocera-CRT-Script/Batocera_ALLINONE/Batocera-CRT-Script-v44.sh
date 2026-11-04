#!/bin/bash

# Batocera CRT Script v44.
# The installer is split by scope so it can be read in pieces.
# Each file is sourced in this order. Nothing in those files was rewritten.
_v44_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/v44"

# TUI banners, colors, and prompts
source "$_v44_dir/01_tui.sh"

# Backup, restore, and the v44 version check
source "$_v44_dir/02_restore.sh"

# Wayland/X11 dual-boot phase 1 and routing
source "$_v44_dir/03_wayland.sh"

# Install /boot/boot-custom.sh when allowed
source "$_v44_dir/04_boot_custom.sh"

# XRandR to DRM output detection
source "$_v44_dir/05_output_detect.sh"

# Dedication and welcome screen
source "$_v44_dir/06_welcome.sh"

# GPU selection, R9 380, and AMD engine pre-scan
source "$_v44_dir/07_gpu.sh"

# Connector bind, Sea Islands, output confirm
source "$_v44_dir/08_connector.sh"

# Monitor type, EDID, and videomodes.conf
source "$_v44_dir/09_monitor_edid.sh"

# Boot resolution, ES resolution, rotation, super-res
source "$_v44_dir/10_resolution_rotation.sh"

# USB polling and syslinux boot files
source "$_v44_dir/11_boot_files.sh"

# Xorg, video.py, and splash
source "$_v44_dir/12_system_files.sh"

# USB encoders and GunCon calibration choices
source "$_v44_dir/13_arcade_inputs.sh"

# CRT Tools files
source "$_v44_dir/14_crt_tools.sh"

# HD/CRT mode switcher install
source "$_v44_dir/15_mode_switcher.sh"

# GunCon2 MAME plugin and shader files
source "$_v44_dir/16_guncon.sh"

# VNC server files
source "$_v44_dir/17_vnc.sh"

# Handheld overlays tool
source "$_v44_dir/18_overlays.sh"

# Media keys and blind CRT-to-HD chord
source "$_v44_dir/19_media_keys.sh"

# Kodi port, overlay save, NVIDIA modeline
source "$_v44_dir/20_ports_nvidia.sh"

# first_script.sh and GunCon launch scripts
source "$_v44_dir/21_first_scripts.sh"

# batocera.conf, RetroArch, and MAME settings
source "$_v44_dir/22_batocera_conf.sh"

# boot-custom, phase 2, and reboot prompt
source "$_v44_dir/23_finalize.sh"
