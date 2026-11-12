# Batocera-CRT-Script v44 - step 06: dualboot phase1
# Dual-boot Phase 1 (Wayland installs): find/download the X11 image, check MD5 and space, extract it to
# /boot/crt, patch the initrd, add the CRT boot entries, deploy batocera-save-crt-overlay (run_phase1).
BETA_BASE="https://mirrors.o2switch.fr/batocera/x86_64/butterfly/last"
STABLE_BASE="https://mirrors.o2switch.fr/batocera/x86_64/stable/last"
find_image() {
    local base="$1"
    curl -s "$base/" \
        | grep -oE "batocera-x86_64-${TARGET_VER}(\.[0-9]+)?-[0-9]+\.img\.gz" \
        | sort -u | tail -1
}
IMG_NAME=$(find_image "$BETA_BASE")
if [ -n "$IMG_NAME" ]; then
    BATO_BASE="$BETA_BASE"; echo "Found v$TARGET_VER on BETA (butterfly): $IMG_NAME"
else
    IMG_NAME=$(find_image "$STABLE_BASE")
    BATO_BASE="$STABLE_BASE"; echo "v$TARGET_VER no longer on butterfly → using STABLE: $IMG_NAME"
fi
if [ -z "$IMG_NAME" ]; then
    echo "ERROR: Batocera v$TARGET_VER not found on either channel" >&2; exit 1
fi
X11_IMAGE_URL="$BATO_BASE/$IMG_NAME"; X11_MD5_URL="$BATO_BASE/${IMG_NAME}.md5"
sanitize_image_url() {
  IMAGE_URL="${IMAGE_URL%.md5}"; IMAGE_URL="${IMAGE_URL% }"
}
scan_for_x11_image() {
  IMAGE_CANDIDATES=""; local IFS_ORIG="$IFS"; IFS=$'\n'
  IMAGE_CANDIDATES=$(find /userdata /media -maxdepth 3 \
    \( -name "batocera-x86_64*.img" -o -name "batocera-x86_64*.img.gz" \
       -o -name "batocera-zen3-x86-64-v3*.img" -o -name "batocera-zen3-x86-64-v3*.img.gz" \
       -o -name "batocera-x86-64-v3*.img" -o -name "batocera-x86-64-v3*.img.gz" \) \
    2>/dev/null | sort)
  IFS="$IFS_ORIG"
}
check_disk_space() {
  local ok=true
  USERDATA_FREE_MB=$(df -m /userdata | awk 'NR==2 {print $4}')
  BOOT_FREE_GB=$(df -BG /boot | awk 'NR==2{print $4}' | tr -d 'G')
  hbox "Disk Space Check"; box_empty
  if [ "$USERDATA_FREE_MB" -lt 5120 ]; then
    box_center "/userdata  needs 5.0GB free  ->  currently $((USERDATA_FREE_MB / 1024))GB free  ${RED}FAIL${NOCOLOR}"
    ok=false
  else box_center "/userdata  needs 5.0GB free  ->  currently $((USERDATA_FREE_MB / 1024))GB free  ${GREEN}OK${NOCOLOR}"; fi
  if [ -d /boot/crt ] && [ -f /boot/crt/linux ] && [ -f /boot/crt/batocera ]; then
    box_center "/boot      /boot/crt/ already populated — space check skipped  ${GREEN}OK${NOCOLOR}"
  elif [ "$BOOT_FREE_GB" -lt 4 ]; then
    box_center "/boot      needs 4.0GB free  ->  currently ${BOOT_FREE_GB}GB free  ${RED}FAIL${NOCOLOR}"; ok=false
  else box_center "/boot      needs 4.0GB free  ->  currently ${BOOT_FREE_GB}GB free  ${GREEN}OK${NOCOLOR}"; fi
  box_empty; box_hash
  if [ "$ok" = false ]; then
    echo ""; box_center "Cannot proceed — not enough free space."; box_center "Free up space then re-run the script."
    echo ""; box_center "Press ENTER to exit."; read -r; exit 1
  fi
}
download_x11_image() {
  local dest_dir="/userdata"; local filename
  filename=$(basename "$IMAGE_URL")
  IMAGE_PATH="${dest_dir}/${filename}"; local part_file="${IMAGE_PATH}.part"; box_hash
  box_center "Downloading X11 Batocera image..."; box_center "(Download time depends on your internet speed)"; box_hash
  echo ""
  while true; do
    rm -f "$part_file"
    if wget --progress=bar:force -O "$part_file" "$IMAGE_URL" 2>&1; then
      write_run 06_dualboot_phase1 image_download_commit mv "$part_file" "$IMAGE_PATH"
      ok_box "Download complete: ${filename}"; local md5_url="${X11_MD5_URL}"
      local md5_dest="${IMAGE_PATH}.md5"
      if wget -q -O "$md5_dest" "$md5_url" 2>/dev/null; then
        ok_box "MD5 checksum downloaded: ${filename}.md5"
      else
        err_box "Warning: could not download .md5 checksum file"; box_center "URL: $md5_url"
        box_center "MD5 validation will fail without this file."
      fi
      return 0
    else
      rm -f "$part_file"; echo ""; err_box "Download failed"; box_empty
      box_center "No changes have been made to your system."; box_center "Partial file deleted."; box_empty; box_hash
      echo ""; echo "  (1) Try again with same URL"; echo "  (2) Enter a different URL"; echo "  (3) Exit"; echo ""
      read -r dl_retry
      case "$dl_retry" in
        1) continue ;;
        2)
          echo ""; echo "  Paste the direct download link for the X11 image (.img.gz, not .md5):"; echo ""
          printf "  URL: "; read -r IMAGE_URL; sanitize_image_url
          filename=$(basename "$IMAGE_URL")
          IMAGE_PATH="${dest_dir}/${filename}"
          part_file="${IMAGE_PATH}.part" ;;
        *) exit 1 ;;
      esac
    fi
  done
}
validate_md5() {
  local md5_file="${IMAGE_PATH}.md5"; hbox "MD5 Validation"; box_empty
  if [ ! -f "$md5_file" ]; then
    err_box "MD5 checksum file not found"; box_center "Expected: ${md5_file}"
    box_center "Transfer the .md5 file alongside the image."; box_empty; box_hash; echo ""; return 1
  fi
  box_center "Checking file against official Batocera checksum..."; box_empty; local official_md5
  official_md5=$(awk '{print $1}' "$md5_file" | tr -d ' \n\r')
  if [ -z "$official_md5" ]; then
    err_box "MD5 file is empty or unreadable"; box_center "File: ${md5_file}"; box_empty; box_hash; echo ""; return 1
  fi
  local local_md5
  local_md5=$(md5sum "$IMAGE_PATH" | cut -d' ' -f1)
  box_center "Expected:  ${official_md5}"; box_center "Got:       ${local_md5}"; box_empty
  if [ "$local_md5" != "$official_md5" ]; then
    err_box "Checksum mismatch — file rejected"; box_center "This file does not match the official X11 checksum."
    box_center "It may be the wrong build, wrong version, or corrupted."; box_center "No changes made."; box_hash
    echo ""; return 1
  fi
  ok_box "Checksum verified. File is the correct X11 build."; return 0
}
prompt_image_source() {
  while true; do
    scan_for_x11_image
    if [ -n "$IMAGE_CANDIDATES" ]; then
      local count
      count=$(echo "$IMAGE_CANDIDATES" | wc -l)
      if [ "$count" -eq 1 ]; then
        local fsize
        fsize=$(du -h "$IMAGE_CANDIDATES" 2>/dev/null | cut -f1)
        local md5_file="${IMAGE_CANDIDATES}.md5"; hbox "X11 Batocera Image Found"; box_empty
        box_center "Image: ${IMAGE_CANDIDATES}  (${fsize})"
        if [ -f "$md5_file" ]; then
          box_center "MD5:   ${md5_file}"; box_empty; box_center "MD5 will be verified against the official Batocera"
          box_center "checksum before use."; box_empty; box_hash; echo ""; echo "  (1) Use this file"
          echo "  (2) Download from official server instead"; echo "  (3) Cancel"
        else
          box_empty; box_center "${RED}MD5 checksum file not found.${NOCOLOR}"
          box_center "You must also transfer the .md5 file from the"
          box_center "Batocera download page to the same location."; box_empty; box_hash; echo ""
          echo "  (1) Scan again — I have added the .md5 file"; echo "  (2) Download from official server instead"
          echo "  (3) Cancel"
        fi
        echo ""; read -r img_choice
        case "$img_choice" in
          1)
            if [ ! -f "$md5_file" ]; then continue; fi
            IMAGE_PATH="$IMAGE_CANDIDATES"
            return 0 ;;
          2) ;;
          *) session_note_cancel phase1_image_selection; exit 0 ;;
        esac
      else
        hbox "Multiple X11 Images Found"; box_empty; local i=1
        echo "$IMAGE_CANDIDATES" | while IFS= read -r f; do
          local sz
          sz=$(du -h "$f" 2>/dev/null | cut -f1)
          box_center "  ($i) ${f}  (${sz})"
          i=$((i + 1))
        done
        box_empty; box_center "  ($((count + 1))) Download from official server instead"
        box_center "  ($((count + 2))) Cancel"; box_hash; echo ""; read -r multi_choice
        if [ "$multi_choice" -ge 1 ] 2>/dev/null && [ "$multi_choice" -le "$count" ]; then
          IMAGE_PATH=$(echo "$IMAGE_CANDIDATES" | sed -n "${multi_choice}p")
          if [ ! -f "${IMAGE_PATH}.md5" ]; then
            echo ""; err_box "MD5 checksum file not found: ${IMAGE_PATH}.md5"
            box_center "Transfer the .md5 file from the Batocera download page"
            box_center "to the same location, then scan again."; box_empty; box_hash; echo ""
            echo "  Press ENTER to scan again..."; read -r; continue
          fi
          return 0
        elif [ "$multi_choice" -eq $((count + 1)) ]; then
          :
        else session_note_cancel phase1_image_selection; exit 0; fi
      fi
    else
      hbox "X11 Image Not Found"; box_empty; box_center "No Batocera x86_64 image found on /userdata or USB drives."
      box_empty; box_center "You can download it directly or transfer manually."; box_empty
      box_center "OPTION A - Let this script download it (recommended)"
      box_center "  Select (2) below. ~4 GB download."; box_empty; box_center "OPTION B - Transfer the image yourself"
      box_empty; box_center "  1. Download the X11 Batocera image AND its .md5 file."
      box_center "     (Both are available on the Batocera download page.)"; box_empty
      box_center "  2. Transfer both files to this machine:"
      box_center "     Windows: WinSCP  ->  wiki.batocera.org/winscp"
      box_center "       Connect: batocera.local | root | linux"; box_center "       Drop files into: /userdata/"
      box_center "     Mac/Linux: scp FILES root@batocera.local:/userdata/"
      box_center "     USB Drive: copy files to USB, plug into this machine"; box_empty
      box_center "  3. Come back here and select (1) to scan again."; box_empty; box_hash; echo ""
      echo "  (1) Scan again — I have transferred the file"; echo "  (2) Download from official server"
      echo "  (3) Exit"; echo ""; read -r nf_choice
      case "$nf_choice" in
        1) continue ;;
        2) ;;
        *) session_note_cancel phase1_image_selection; exit 0 ;;
      esac
    fi
    IMAGE_URL="$X11_IMAGE_URL"; hbox "Download X11 Batocera Image"; box_empty; box_center "Image: ${IMAGE_URL}"
    box_center "MD5:   ${X11_MD5_URL}"; box_empty; box_hash; echo ""; echo "  (1) Yes, download"; echo "  (2) Cancel"
    echo ""; read -r confirm_dl
    case "$confirm_dl" in
      1)
        check_disk_space
        download_x11_image
        return 0 ;;
      *) session_note_cancel phase1_image_selection; exit 0 ;;
    esac
  done
}
extract_x11_to_boot_crt() {
  if [ -f /boot/crt/linux ] && [ -f /boot/crt/batocera ] && \
     [ -f /boot/crt/rufomaculata ] && [ -f /boot/crt/initrd-crt.gz ]; then
    hbox "Extracting X11 boot files to /boot/crt/"; box_empty
    box_center "/boot/crt/ already contains all required files — skipping extraction"; box_empty
    ok_box "Boot files verified in /boot/crt/"; return 0
  fi
  hbox "Extracting X11 boot files to /boot/crt/"; box_empty; box_center "Source: ${IMAGE_PATH}"; box_empty
  local img_file="$IMAGE_PATH"; local decompressed=""
  if echo "$img_file" | grep -q '\.img\.gz$'; then
    box_center "Decompressing image (this may take a few minutes)..."; decompressed="${img_file%.gz}"
    gunzip -k "$img_file" || { err_box "Failed to decompress image"; exit 1; }; img_file="$decompressed"
  fi
  local vfat_start
  vfat_start=$(parted -s "$img_file" unit s print 2>/dev/null | awk '/fat32/{print $2}' | tr -d 's' | head -1)
  if [ -z "$vfat_start" ]; then
    [ -n "$decompressed" ] && rm -f "$decompressed"; err_box "Could not find VFAT partition in image"; exit 1
  fi
  local offset=$((vfat_start * 512))
  local mnt="/tmp/crt-img-mount"; mkdir -p "$mnt"
  if ! mount -o loop,ro,offset=$offset "$img_file" "$mnt"; then
    [ -n "$decompressed" ] && rm -f "$decompressed"; err_box "Failed to mount image VFAT partition"; exit 1
  fi
  for req_file in boot/batocera boot/rufomaculata boot/linux boot/initrd.gz; do
    if [ ! -f "$mnt/$req_file" ]; then
      umount "$mnt" 2>/dev/null; [ -n "$decompressed" ] && rm -f "$decompressed"
      err_box "Missing expected file: ${req_file}"; exit 1
    fi
  done
  # Do not use the legacy remount_boot_rw helper here: it masks mount failures.
  write_run 06_dualboot_phase1 phase1_boot_remount mount -o remount,rw /boot
  write_run 06_dualboot_phase1 phase1_crt_dir_create mkdir -p /boot/crt
  box_center "Copying batocera (X11 squashfs ~3.2GB)..."
  cp "$mnt/boot/batocera" /boot/crt/batocera || { umount "$mnt"; err_box "Copy failed: batocera"; exit 1; }
  box_center "Copying rufomaculata (board squashfs ~1.1GB)..."
  cp "$mnt/boot/rufomaculata" /boot/crt/rufomaculata || { umount "$mnt"; err_box "Copy failed: rufomaculata"; exit 1; }
  box_center "Copying linux (X11 kernel ~23MB)..."
  cp "$mnt/boot/linux" /boot/crt/linux || { umount "$mnt"; err_box "Copy failed: linux"; exit 1; }
  box_center "Copying initrd.gz (staging for patch)..."
  cp "$mnt/boot/initrd.gz" /boot/crt/initrd-src.gz || { umount "$mnt"; err_box "Copy failed: initrd.gz"; exit 1; }
  write_run 06_dualboot_phase1 image_source_unmount umount "$mnt"
  rmdir "$mnt" 2>/dev/null; [ -n "$decompressed" ] && rm -f "$decompressed"; local magic
  magic=$(xxd -l 4 /boot/crt/batocera 2>/dev/null | awk '{print $2$3}' | cut -c1-8)
  if [ "$magic" != "68737173" ]; then
    err_box "Extracted batocera file is not a valid squashfs"; rm -rf /boot/crt; exit 1
  fi
  ok_box "Boot files extracted to /boot/crt/"
}
patch_initrd() {
  if [ -f /boot/crt/initrd-crt.gz ] && [ ! -f /boot/crt/initrd-src.gz ]; then
    hbox "Patching initrd for CRT boot path"; box_empty; box_center "initrd-crt.gz already exists — skipping patch"
    box_empty; ok_box "Patched initrd verified in /boot/crt/"; return 0
  fi
  hbox "Patching initrd for CRT boot path"; box_empty; local workdir="/tmp/initrd-crt-work"; rm -rf "$workdir"
  mkdir -p "$workdir/extracted"; cd "$workdir/extracted" || exit 1
  if ! (set -o pipefail; gunzip < /boot/crt/initrd-src.gz | bsdtar -xf - 2>/dev/null); then
    write_abort 06_dualboot_phase1 initrd_extract 1
  fi
  if [ ! -f init ]; then
    err_box "initrd does not contain an init script"; cd /; rm -rf "$workdir"; exit 1
  fi
  local before_count
  before_count=$(grep -c '/boot_root/boot/' init 2>/dev/null || echo 0)
  write_run 06_dualboot_phase1 initrd_patch_paths sed -i 's|/boot_root/boot/|/boot_root/crt/|g' init
  local after_count
  after_count=$(grep -c '/boot_root/boot/' init 2>/dev/null || echo 0)
  box_center "Patched ${before_count} path references (${after_count} remaining)"
  write_run 06_dualboot_phase1 initrd_archive_pack bsdtar --format=newc -cf /tmp/initrd-crt.cpio .
  gzip -9 < /tmp/initrd-crt.cpio > /boot/crt/initrd-crt.gz || write_abort 06_dualboot_phase1 initrd_archive_gzip "$?"
  write_run 06_dualboot_phase1 initrd_archive_integrity gzip -t /boot/crt/initrd-crt.gz
  rm -f /tmp/initrd-crt.cpio
  if [ ! -s /boot/crt/initrd-crt.gz ]; then
    err_box "Failed to create initrd-crt.gz"; cd /; rm -rf "$workdir"; exit 1
  fi
  cd /; rm -rf "$workdir"; rm -f /boot/crt/initrd-src.gz; ok_box "initrd-crt.gz created at /boot/crt/initrd-crt.gz"
}
deploy_crt_overlay_script() {
  local target="${CRT_SCRIPT_DIR}/batocera-save-crt-overlay"
  write_run 06_dualboot_phase1 overlay_writer_directory mkdir -p "$CRT_SCRIPT_DIR"
  if [ -L "$target" ]; then write_abort 06_dualboot_phase1 unsafe_overlay_writer_target 1; fi
  cat > "$target" <<'OVERLAY_SCRIPT' || write_abort 06_dualboot_phase1 overlay_writer_write "$?"
#!/bin/sh
OVERLAYFILE="/boot/crt/overlay"
OVERLAYMOUNT="/overlay/saved"
OVERLAYRAM="/overlay/overlay"
OVERLAYSIZE=100 # M

PATH=$PATH:/sbin

createOverlayIfNeeded() {
    COISIZE=$1
    test -e "${OVERLAYFILE}" && return 0
    echo "Creating an overlay file on the /boot filesystem..."
    dd if=/dev/zero of="${OVERLAYFILE}" bs=${COISIZE}M count=1 || return 1
    echo "Formating the overlay file in ext4..."
    mkfs.ext4 "${OVERLAYFILE}"                         || return 1
}

echo "Making /boot writable..."
if ! mount -o remount,rw /boot
then
    exit 1
fi

if test $# -eq 1
then
    if echo "$1" | grep -qE '[1-9][0-9]*'
       then
           echo "removing the existing overlay"
           rm -f "${OVERLAYFILE}" || exit 1
           OVERLAYSIZE=$1
    fi
fi

if ! createOverlayIfNeeded "${OVERLAYSIZE}"
then
    mount -o remount,ro /boot
    exit 1
fi

echo "Mounting the overlay file..."
if ! mount -o rw "${OVERLAYFILE}" "${OVERLAYMOUNT}"
then
    mount -o remount,ro /boot
    exit 1
fi

echo "Saving the real overlay to disk..."
if ! rsync -av --delete --exclude="/.cache" "${OVERLAYRAM}/" "${OVERLAYMOUNT}"
then
    umount "${OVERLAYMOUNT}"
    mount -o remount,ro /boot
    exit 1
fi

echo "Umounting the overlay file..."
if ! umount "${OVERLAYMOUNT}"
then
    mount -o remount,ro /boot
    exit 1
fi

echo "Making /boot read only..."
if ! mount -o remount,ro /boot
then
    exit 1
fi

echo "Synchronizing..."
sync

echo "Success."
exit 0
OVERLAY_SCRIPT
  write_run 06_dualboot_phase1 overlay_writer_permissions chmod 755 "$target"
  [ -f "$target" ] && [ -x "$target" ] && [ -s "$target" ] || write_abort 06_dualboot_phase1 overlay_writer_readback 1
  ok_box "batocera-save-crt-overlay deployed to ${target}"
}
write_phase1_syslinux_valid() {
  local path="$1"
  awk '
    /^DEFAULT crt$/ { defaults++ }
    /^LABEL crt$/ { labels++; active=1; next }
    /^LABEL / { active=0 }
    active && /^[[:space:]]*LINUX \/crt\/linux$/ { kernel++ }
    active && /^[[:space:]]*INITRD \/crt\/initrd-crt\.gz$/ { initrd++ }
    active && /^[[:space:]]*APPEND / { append++ }
    active && /^[[:space:]]*MENU DEFAULT$/ { menu++ }
    END { exit !(defaults==1 && labels==1 && kernel==1 && initrd==1 && append==1 && menu==1) }
  ' "$path"
}
write_phase1_boot_files_valid() {
  local file magic
  for file in batocera rufomaculata linux initrd-crt.gz; do
    [ -f "/boot/crt/$file" ] && [ ! -L "/boot/crt/$file" ] && [ -s "/boot/crt/$file" ] || return 1
  done
  for file in batocera rufomaculata; do
    magic=$(od -An -tx1 -N4 "/boot/crt/$file" 2>/dev/null | tr -d ' \n')
    [ "$magic" = 68737173 ] || return 1
  done
  gzip -t /boot/crt/initrd-crt.gz >/dev/null 2>&1
}
update_boot_config() {
  hbox "Updating boot configuration"; box_empty
  write_run 06_dualboot_phase1 boot_entry_remount mount -o remount,rw /boot
  local syslinux_files=""; local f
  for f in /boot/EFI/batocera/syslinux.cfg \
           /boot/boot/syslinux.cfg \
           /boot/boot/syslinux/syslinux.cfg; do [ -f "$f" ] && syslinux_files="$syslinux_files $f"; done
  if [ -z "$syslinux_files" ]; then
    err_box "No syslinux.cfg found on boot partition"; exit 1
  fi
  local parent_dir
  for f in $syslinux_files; do
    parent_dir="$(basename "$(dirname "$f")")"
    if grep -q '^LABEL crt' "$f" 2>/dev/null; then
      box_center "CRT entry already in ${parent_dir}/syslinux.cfg — skipping"
    else
      sed -i 's/Batocera\.linux (\^normal)/Batocera HD - Wayland (^normal)/' "$f" || write_abort 06_dualboot_phase1 boot_entry_edit "$?"
      sed -i 's/Batocera\.linux (\^verbose)/Batocera HD - Wayland (^verbose)/' "$f" || write_abort 06_dualboot_phase1 boot_entry_edit "$?"
      cat >> "$f" <<'CRTSYSLINUX' || write_abort 06_dualboot_phase1 boot_entry_append "$?"

LABEL crt
	MENU LABEL Batocera CRT (X11)
	LINUX /crt/linux
	APPEND label=BATOCERA console=tty3 quiet loglevel=0 vt.global_cursor_default=0
	INITRD /crt/initrd-crt.gz
CRTSYSLINUX
      box_center "CRT entry added to ${parent_dir}/syslinux.cfg"
    fi
    write_run 06_dualboot_phase1 boot_menu_reset sed -i '/^[[:space:]]*MENU DEFAULT[[:space:]]*$/d' "$f"
    write_run 06_dualboot_phase1 boot_menu_default sed -i '/^LABEL crt$/a\	MENU DEFAULT' "$f"
    if grep -q '^DEFAULT ' "$f"; then
      sed -i 's/^DEFAULT .*/DEFAULT crt/' "$f" || write_abort 06_dualboot_phase1 boot_entry_edit "$?"
    else
      write_run 06_dualboot_phase1 boot_default_insert sed -i '1i\DEFAULT crt' "$f"
    fi
    write_run 06_dualboot_phase1 boot_entry_readback write_phase1_syslinux_valid "$f"
    box_center "Default set to CRT in ${parent_dir}/syslinux.cfg"
  done
  if [ -d /sys/firmware/efi ]; then
    local grub_cfg="/boot/EFI/BOOT/grub.cfg"
    if [ -f "$grub_cfg" ]; then
      if ! grep -q 'Batocera CRT (X11)' "$grub_cfg" 2>/dev/null; then
        sed -i 's/menuentry "Batocera\.linux (normal)"/menuentry "Batocera HD (Wayland)"/' "$grub_cfg" || write_abort 06_dualboot_phase1 boot_entry_edit "$?"
        sed -i 's/menuentry "Batocera\.linux (verbose)"/menuentry "Batocera HD (verbose)"/' "$grub_cfg" || write_abort 06_dualboot_phase1 boot_entry_edit "$?"
        sed -i 's/set timeout="1"/set timeout="3"/' "$grub_cfg" || write_abort 06_dualboot_phase1 boot_entry_edit "$?"; local insert_line
        insert_line=$(awk '/Batocera HD \(Wayland\)/{found=1} found && /^\}/{print NR; exit}' "$grub_cfg")
        if [ -n "$insert_line" ]; then
          sed -i "${insert_line}a\\
\\
menuentry \"Batocera CRT (X11)\" {\\
    echo Booting Batocera.linux... CRT Mode (X11)\\
    linux /crt/linux label=BATOCERA console=tty3 quiet loglevel=0 vt.global_cursor_default=0\\
    initrd /crt/initrd-crt.gz\\
}" "$grub_cfg" || write_abort 06_dualboot_phase1 grub_entry_insert "$?"
        else
          cat >> "$grub_cfg" <<'CRTENTRY' || write_abort 06_dualboot_phase1 grub_entry_append "$?"

menuentry "Batocera CRT (X11)" {
    echo Booting Batocera.linux... CRT Mode (X11)
    linux /crt/linux label=BATOCERA console=tty3 quiet loglevel=0 vt.global_cursor_default=0
    initrd /crt/initrd-crt.gz
}
CRTENTRY
        fi
      fi
      write_run 06_dualboot_phase1 grub_default_edit sed -i 's/set default="0"/set default="1"/' "$grub_cfg"
      grep -q 'Batocera CRT (X11)' "$grub_cfg" || write_abort 06_dualboot_phase1 grub_entry_readback 1
      box_center "grub.cfg fallback also updated"
    fi
  fi
  write_run 06_dualboot_phase1 boot_entry_remount_ro mount -o remount,ro /boot
  box_empty; ok_box "Boot configuration updated (syslinux)"
}
prompt_cleanup_source_image() {
  local md5_file="${IMAGE_PATH}.md5"; hbox "Cleanup"; box_empty; local fsize
  fsize=$(du -h "$IMAGE_PATH" 2>/dev/null | cut -f1)
  box_center "Source image: ${IMAGE_PATH}  (${fsize})"
  if [ -f "$md5_file" ]; then box_center "MD5 file:     ${md5_file}"; fi
  box_empty; box_center "The boot files have been extracted successfully."
  box_center "The source image is no longer needed."; box_empty; box_center "Delete it to free up space on /userdata/?"
  box_empty; box_hash; echo ""; echo "  (1) Yes, delete it — reclaim ${fsize} on /userdata"
  echo "  (2) No, keep it — useful if you may need to reinstall later"; echo ""; read -r cleanup_choice
  if [ "$cleanup_choice" = "1" ]; then
    rm -f "$IMAGE_PATH"; rm -f "$md5_file"; ok_box "Source image and MD5 file deleted."
  else box_center "Source image kept at: ${IMAGE_PATH}"; fi
}
run_phase1() {
  box_hash; box_center "Dual-Boot Install — Phase 1 of 2"
  box_center "Setting up X11 boot environment alongside Wayland"; box_hash; echo ""; sleep 1
  if [ ! -s /userdata/Batocera-CRT-Script-Backup/mode_backups/hd_mode/video_settings/hd_mode_list.txt ]; then
    session_phase1_step hd_monitor_capture capture_hd_monitor_list || write_abort 06_dualboot_phase1 hd_monitor_capture "$?"
  fi
  session_phase1_step image_source_selection prompt_image_source || write_abort 06_dualboot_phase1 image_source_selection "$?"
  if ! session_phase1_step image_checksum_check validate_md5; then
    diag_event 06_dualboot_phase1 image_checksum image_checksum_check failed
    echo ""; echo "  (1) Continue without MD5 verification"; echo "  (2) Abort"; echo ""; read -r md5_choice
    case "$md5_choice" in
      1) if declare -F log_event >/dev/null 2>&1; then
           log_event WARN 06_dualboot_phase1 image_checksum_override outcome skipped reason user_override || :
         fi
         echo "  Proceeding without checksum verification..." ;;
      *) if declare -F log_event >/dev/null 2>&1; then
           log_event ERROR 06_dualboot_phase1 image_checksum_override outcome cancelled reason checksum_rejected || :
         fi
         exit 1 ;;
    esac
  else
    diag_event 06_dualboot_phase1 image_checksum image_checksum_check passed
  fi
  session_phase1_step disk_space_check check_disk_space || write_abort 06_dualboot_phase1 disk_space_check "$?"
  session_phase1_step x11_image_extract extract_x11_to_boot_crt || write_abort 06_dualboot_phase1 x11_image_extract "$?"
  session_phase1_step crt_initrd_patch patch_initrd || write_abort 06_dualboot_phase1 crt_initrd_patch "$?"
  session_phase1_step boot_entry_update update_boot_config || write_abort 06_dualboot_phase1 boot_entry_update "$?"
  session_phase1_step crt_overlay_writer_deploy deploy_crt_overlay_script || write_abort 06_dualboot_phase1 crt_overlay_writer_deploy "$?"
  # These presence probes document observed state; they are not a Phase 1
  # integrity gate and cannot independently validate the kernel/boot images.
  session_phase1_probes
  # A read-only check before marking Phase 1 pending. Not proof of bootability.
  write_run 06_dualboot_phase1 phase1_boot_payload_readback write_phase1_boot_files_valid
  session_phase1_step source_image_cleanup prompt_cleanup_source_image
  session_set_step phase1_marker_write
  write_run 06_dualboot_phase1 phase1_marker_directory mkdir -p "$(dirname "$PHASE_FLAG")"
  printf '%s\n' 2 > "$PHASE_FLAG" || write_abort 06_dualboot_phase1 phase1_marker_write "$?"
  echo ""
  if [[ -f "$PHASE_FLAG" && "$(cat "$PHASE_FLAG" 2>/dev/null)" == 2 ]]; then
    diag_event 06_dualboot_phase1 phase1_marker phase1_marker_write present
  else
    diag_event 06_dualboot_phase1 phase1_marker phase1_marker_write missing
    err_box "Phase 1 marker was not saved. Installation cannot hand off to Phase 2."
    exit 1
  fi
  hbox "${GREEN}${BOLD}Phase 1 Complete!${NOCOLOR}"; box_empty; box_center "The X11 boot environment is installed."
  box_center "Boot is configured to load X11 on next restart."; box_empty; box_center "WHAT HAPPENS NEXT:"; box_empty
  box_center "1) System SHUTS DOWN."; box_center "2) Press the POWER BUTTON to boot into X11."
  box_center "3) Re-run this CRT Script from X11."; box_center "   It will detect Phase 2 automatically and continue"
  box_center "   with CRT display configuration."; box_empty; box_center "Your ROMs, saves, and BIOS files are shared."
  box_center "Nothing from your Wayland install is lost."; box_empty; box_hash; box_empty
  # Phase 1 is a pending Phase 2 handoff, not a verified installation.
  session_phase1_handoff
  box_center "${GREEN}${BOLD}Press ENTER to shut down...${NOCOLOR}"; box_empty; box_hash; echo ""; read -r
  _dualboot_installer_poweroff
}
