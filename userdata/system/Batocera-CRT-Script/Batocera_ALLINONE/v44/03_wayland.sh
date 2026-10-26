########################################################################################
#####################    WAYLAND / X11 PHASE 1 FUNCTIONS START     ####################
########################################################################################

# Target Batocera major version
if ([ "$Version_of_batocera" == "v44" ]); then
{
   TARGET_VER="44"
}
else
{
   echo "Wrong Version"
}
fi

# Channel bases
BETA_BASE="https://mirrors.o2switch.fr/batocera/x86_64/butterfly/last"
STABLE_BASE="https://mirrors.o2switch.fr/batocera/x86_64/stable/last"
# Helper: return the image filename for $TARGET_VER in a given base, or empty
find_image() {
    local base="$1"
    curl -s "$base/" \
        | grep -oE "batocera-x86_64-${TARGET_VER}(\.[0-9]+)?-[0-9]+\.img\.gz" \
        | sort -u | tail -1
}

# Prefer beta (butterfly) if it still carries version 44, else use stable
IMG_NAME=$(find_image "$BETA_BASE")
if [ -n "$IMG_NAME" ]; then
    BATO_BASE="$BETA_BASE"
    echo "Found v$TARGET_VER on BETA (butterfly): $IMG_NAME"
else
    IMG_NAME=$(find_image "$STABLE_BASE")
    BATO_BASE="$STABLE_BASE"
    echo "v$TARGET_VER no longer on butterfly → using STABLE: $IMG_NAME"
fi

if [ -z "$IMG_NAME" ]; then
    echo "ERROR: Batocera v$TARGET_VER not found on either channel" >&2
    exit 1
fi

X11_IMAGE_URL="$BATO_BASE/$IMG_NAME"
X11_MD5_URL="$BATO_BASE/${IMG_NAME}.md5"

sanitize_image_url() {
  IMAGE_URL="${IMAGE_URL%.md5}"
  IMAGE_URL="${IMAGE_URL% }"
}


scan_for_x11_image() {
  IMAGE_CANDIDATES=""
  local IFS_ORIG="$IFS"
  IFS=$'\n'
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

  box_hash
  box_center "Disk Space Check"
  box_hash
  box_empty

  if [ "$USERDATA_FREE_MB" -lt 5120 ]; then
    box_center "/userdata  needs 5.0GB free  ->  currently $((USERDATA_FREE_MB / 1024))GB free  ${RED}FAIL${NOCOLOR}"
    ok=false
  else
    box_center "/userdata  needs 5.0GB free  ->  currently $((USERDATA_FREE_MB / 1024))GB free  ${GREEN}OK${NOCOLOR}"
  fi

  if [ -d /boot/crt ] && [ -f /boot/crt/linux ] && [ -f /boot/crt/batocera ]; then
    box_center "/boot      /boot/crt/ already populated — space check skipped  ${GREEN}OK${NOCOLOR}"
  elif [ "$BOOT_FREE_GB" -lt 4 ]; then
    box_center "/boot      needs 4.0GB free  ->  currently ${BOOT_FREE_GB}GB free  ${RED}FAIL${NOCOLOR}"
    ok=false
  else
    box_center "/boot      needs 4.0GB free  ->  currently ${BOOT_FREE_GB}GB free  ${GREEN}OK${NOCOLOR}"
  fi

  box_empty
  box_hash

  if [ "$ok" = false ]; then
    echo ""
    box_center "Cannot proceed — not enough free space."
    box_center "Free up space then re-run the script."
    echo ""
    box_center "Press ENTER to exit."
    read -r
    exit 1
  fi
}

download_x11_image() {
  local dest_dir="/userdata"
  local filename
  filename=$(basename "$IMAGE_URL")
  IMAGE_PATH="${dest_dir}/${filename}"
  local part_file="${IMAGE_PATH}.part"

  box_hash
  box_center "Downloading X11 Batocera image..."
  box_center "(Download time depends on your internet speed)"
  box_hash
  echo ""

  while true; do
    rm -f "$part_file"
    if wget --progress=bar:force -O "$part_file" "$IMAGE_URL" 2>&1; then
      mv "$part_file" "$IMAGE_PATH"
      ok_box "Download complete: ${filename}"
      # Also download the .md5 file from the official mirror
      local md5_url="${X11_MD5_URL}"
      local md5_dest="${IMAGE_PATH}.md5"
      if wget -q -O "$md5_dest" "$md5_url" 2>/dev/null; then
        ok_box "MD5 checksum downloaded: ${filename}.md5"
      else
        err_box "Warning: could not download .md5 checksum file"
        box_center "URL: $md5_url"
        box_center "MD5 validation will fail without this file."
      fi
      return 0
    else
      rm -f "$part_file"
      echo ""
      err_box "Download failed"
      box_empty
      box_center "No changes have been made to your system."
      box_center "Partial file deleted."
      box_empty
      box_hash
      echo ""
      echo "  (1) Try again with same URL"
      echo "  (2) Enter a different URL"
      echo "  (3) Exit"
      echo ""
      read -r dl_retry
      case "$dl_retry" in
        1) continue ;;
        2)
          echo ""
          echo "  Paste the direct download link for the X11 image (.img.gz, not .md5):"
          echo ""
          printf "  URL: "
          read -r IMAGE_URL
          sanitize_image_url
          filename=$(basename "$IMAGE_URL")
          IMAGE_PATH="${dest_dir}/${filename}"
          part_file="${IMAGE_PATH}.part"
          ;;
        *) exit 1 ;;
      esac
    fi
  done
}

validate_md5() {
  local md5_file="${IMAGE_PATH}.md5"

  box_hash
  box_center "MD5 Validation"
  box_hash
  box_empty

  if [ ! -f "$md5_file" ]; then
    err_box "MD5 checksum file not found"
    box_center "Expected: ${md5_file}"
    box_center "Transfer the .md5 file alongside the image."
    box_empty
    box_hash
    echo ""
    return 1
  fi

  box_center "Checking file against official Batocera checksum..."
  box_empty

  local official_md5
  official_md5=$(awk '{print $1}' "$md5_file" | tr -d ' \n\r')

  if [ -z "$official_md5" ]; then
    err_box "MD5 file is empty or unreadable"
    box_center "File: ${md5_file}"
    box_empty
    box_hash
    echo ""
    return 1
  fi

  local local_md5
  local_md5=$(md5sum "$IMAGE_PATH" | cut -d' ' -f1)

  box_center "Expected:  ${official_md5}"
  box_center "Got:       ${local_md5}"
  box_empty

  if [ "$local_md5" != "$official_md5" ]; then
    err_box "Checksum mismatch — file rejected"
    box_center "This file does not match the official X11 checksum."
    box_center "It may be the wrong build, wrong version, or corrupted."
    box_center "No changes made."
    box_hash
    echo ""
    return 1
  fi

  ok_box "Checksum verified. File is the correct X11 build."
  return 0
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
        local md5_file="${IMAGE_CANDIDATES}.md5"
        box_hash
        box_center "X11 Batocera Image Found"
        box_hash
        box_empty
        box_center "Image: ${IMAGE_CANDIDATES}  (${fsize})"
        if [ -f "$md5_file" ]; then
          box_center "MD5:   ${md5_file}"
          box_empty
          box_center "MD5 will be verified against the official Batocera"
          box_center "checksum before use."
          box_empty
          box_hash
          echo ""
          echo "  (1) Use this file"
          echo "  (2) Download from official server instead"
          echo "  (3) Cancel"
        else
          box_empty
          box_center "${RED}MD5 checksum file not found.${NOCOLOR}"
          box_center "You must also transfer the .md5 file from the"
          box_center "Batocera download page to the same location."
          box_empty
          box_hash
          echo ""
          echo "  (1) Scan again — I have added the .md5 file"
          echo "  (2) Download from official server instead"
          echo "  (3) Cancel"
        fi
        echo ""
        read -r img_choice
        case "$img_choice" in
          1)
            if [ ! -f "$md5_file" ]; then
              continue
            fi
            IMAGE_PATH="$IMAGE_CANDIDATES"
            return 0
            ;;
          2) ;; # fall through to URL prompt below
          *) exit 0 ;;
        esac
      else
        box_hash
        box_center "Multiple X11 Images Found"
        box_hash
        box_empty
        local i=1
        echo "$IMAGE_CANDIDATES" | while IFS= read -r f; do
          local sz
          sz=$(du -h "$f" 2>/dev/null | cut -f1)
          box_center "  ($i) ${f}  (${sz})"
          i=$((i + 1))
        done
        box_empty
        box_center "  ($((count + 1))) Download from official server instead"
        box_center "  ($((count + 2))) Cancel"
        box_hash
        echo ""
        read -r multi_choice
        if [ "$multi_choice" -ge 1 ] 2>/dev/null && [ "$multi_choice" -le "$count" ]; then
          IMAGE_PATH=$(echo "$IMAGE_CANDIDATES" | sed -n "${multi_choice}p")
          if [ ! -f "${IMAGE_PATH}.md5" ]; then
            echo ""
            err_box "MD5 checksum file not found: ${IMAGE_PATH}.md5"
            box_center "Transfer the .md5 file from the Batocera download page"
            box_center "to the same location, then scan again."
            box_empty
            box_hash
            echo ""
            echo "  Press ENTER to scan again..."
            read -r
            continue
          fi
          return 0
        elif [ "$multi_choice" -eq $((count + 1)) ]; then
          : # fall through to URL prompt
        else
          exit 0
        fi
      fi
    else
      box_hash
      box_center "X11 Image Not Found"
      box_hash
      box_empty
      box_center "No Batocera x86_64 image found on /userdata or USB drives."
      box_empty
      box_center "You can download it directly or transfer manually."
      box_empty
      box_center "OPTION A - Let this script download it (recommended)"
      box_center "  Select (2) below. ~4 GB download."
      box_empty
      box_center "OPTION B - Transfer the image yourself"
      box_empty
      box_center "  1. Download the X11 Batocera image AND its .md5 file."
      box_center "     (Both are available on the Batocera download page.)"
      box_empty
      box_center "  2. Transfer both files to this machine:"
      box_center "     Windows: WinSCP  ->  wiki.batocera.org/winscp"
      box_center "       Connect: batocera.local | root | linux"
      box_center "       Drop files into: /userdata/"
      box_center "     Mac/Linux: scp FILES root@batocera.local:/userdata/"
      box_center "     USB Drive: copy files to USB, plug into this machine"
      box_empty
      box_center "  3. Come back here and select (1) to scan again."
      box_empty
      box_hash
      echo ""
      echo "  (1) Scan again — I have transferred the file"
      echo "  (2) Download from official server"
      echo "  (3) Exit"
      echo ""
      read -r nf_choice
      case "$nf_choice" in
        1) continue ;; # loop back to scan
        2) ;; # fall through to URL prompt
        *) exit 0 ;;
      esac
    fi

    IMAGE_URL="$X11_IMAGE_URL"

    box_hash
    box_center "Download X11 Batocera Image"
    box_hash
    box_empty
    box_center "Image: ${IMAGE_URL}"
    box_center "MD5:   ${X11_MD5_URL}"
    box_empty
    box_hash
    echo ""
    echo "  (1) Yes, download"
    echo "  (2) Cancel"
    echo ""
    read -r confirm_dl
    case "$confirm_dl" in
      1)
        check_disk_space
        download_x11_image
        return 0
        ;;
      *) exit 0 ;;
    esac
  done
}

extract_x11_to_boot_crt() {
  # Skip if /boot/crt/ is already fully populated (idempotent re-run)
  if [ -f /boot/crt/linux ] && [ -f /boot/crt/batocera ] && \
     [ -f /boot/crt/rufomaculata ] && [ -f /boot/crt/initrd-crt.gz ]; then
    box_hash
    box_center "Extracting X11 boot files to /boot/crt/"
    box_hash
    box_empty
    box_center "/boot/crt/ already contains all required files — skipping extraction"
    box_empty
    ok_box "Boot files verified in /boot/crt/"
    return 0
  fi

  box_hash
  box_center "Extracting X11 boot files to /boot/crt/"
  box_hash
  box_empty
  box_center "Source: ${IMAGE_PATH}"
  box_empty

  local img_file="$IMAGE_PATH"
  local decompressed=""

  # If .img.gz, decompress first
  if echo "$img_file" | grep -q '\.img\.gz$'; then
    box_center "Decompressing image (this may take a few minutes)..."
    decompressed="${img_file%.gz}"
    gunzip -k "$img_file" || { err_box "Failed to decompress image"; exit 1; }
    img_file="$decompressed"
  fi

  # Find VFAT partition offset
  local vfat_start
  vfat_start=$(parted -s "$img_file" unit s print 2>/dev/null | awk '/fat32/{print $2}' | tr -d 's' | head -1)
  if [ -z "$vfat_start" ]; then
    [ -n "$decompressed" ] && rm -f "$decompressed"
    err_box "Could not find VFAT partition in image"
    exit 1
  fi
  local offset=$((vfat_start * 512))

  # Mount VFAT partition
  local mnt="/tmp/crt-img-mount"
  mkdir -p "$mnt"
  if ! mount -o loop,ro,offset=$offset "$img_file" "$mnt"; then
    [ -n "$decompressed" ] && rm -f "$decompressed"
    err_box "Failed to mount image VFAT partition"
    exit 1
  fi

  # Verify source files exist
  for req_file in boot/batocera boot/rufomaculata boot/linux boot/initrd.gz; do
    if [ ! -f "$mnt/$req_file" ]; then
      umount "$mnt" 2>/dev/null
      [ -n "$decompressed" ] && rm -f "$decompressed"
      err_box "Missing expected file: ${req_file}"
      exit 1
    fi
  done

  # Remount /boot read-write
  remount_boot_rw

  # Create destination
  mkdir -p /boot/crt

  # Copy files
  box_center "Copying batocera (X11 squashfs ~3.2GB)..."
  cp "$mnt/boot/batocera"     /boot/crt/batocera     || { umount "$mnt"; err_box "Copy failed: batocera"; exit 1; }

  box_center "Copying rufomaculata (board squashfs ~1.1GB)..."
  cp "$mnt/boot/rufomaculata" /boot/crt/rufomaculata || { umount "$mnt"; err_box "Copy failed: rufomaculata"; exit 1; }

  box_center "Copying linux (X11 kernel ~23MB)..."
  cp "$mnt/boot/linux"        /boot/crt/linux        || { umount "$mnt"; err_box "Copy failed: linux"; exit 1; }

  box_center "Copying initrd.gz (staging for patch)..."
  cp "$mnt/boot/initrd.gz"    /boot/crt/initrd-src.gz || { umount "$mnt"; err_box "Copy failed: initrd.gz"; exit 1; }

  # Unmount and clean up decompressed image
  umount "$mnt"
  rmdir "$mnt" 2>/dev/null
  [ -n "$decompressed" ] && rm -f "$decompressed"

  # Verify squashfs magic bytes (hsqs = 68737173 in hex)
  local magic
  magic=$(xxd -l 4 /boot/crt/batocera 2>/dev/null | awk '{print $2$3}' | cut -c1-8)
  if [ "$magic" != "68737173" ]; then
    err_box "Extracted batocera file is not a valid squashfs"
    rm -rf /boot/crt
    exit 1
  fi

  ok_box "Boot files extracted to /boot/crt/"
}

patch_initrd() {
  # Skip if initrd-crt.gz already exists and initrd-src.gz is absent (already patched)
  if [ -f /boot/crt/initrd-crt.gz ] && [ ! -f /boot/crt/initrd-src.gz ]; then
    box_hash
    box_center "Patching initrd for CRT boot path"
    box_hash
    box_empty
    box_center "initrd-crt.gz already exists — skipping patch"
    box_empty
    ok_box "Patched initrd verified in /boot/crt/"
    return 0
  fi

  box_hash
  box_center "Patching initrd for CRT boot path"
  box_hash
  box_empty

  local workdir="/tmp/initrd-crt-work"
  rm -rf "$workdir"
  mkdir -p "$workdir/extracted"

  # Unpack using bsdtar (cpio is not available on the Wayland build)
  cd "$workdir/extracted" || exit 1
  gunzip < /boot/crt/initrd-src.gz | bsdtar -xf - 2>/dev/null

  if [ ! -f init ]; then
    err_box "initrd does not contain an init script"
    cd /
    rm -rf "$workdir"
    exit 1
  fi

  # Count replacements for verification
  local before_count
  before_count=$(grep -c '/boot_root/boot/' init 2>/dev/null || echo 0)

  # Patch: all /boot_root/boot/ → /boot_root/crt/
  sed -i 's|/boot_root/boot/|/boot_root/crt/|g' init

  local after_count
  after_count=$(grep -c '/boot_root/boot/' init 2>/dev/null || echo 0)

  box_center "Patched ${before_count} path references (${after_count} remaining)"

  # Repack as cpio newc + gzip using bsdtar
  bsdtar --format=newc -cf /tmp/initrd-crt.cpio . 2>/dev/null
  gzip -9 < /tmp/initrd-crt.cpio > /boot/crt/initrd-crt.gz
  rm -f /tmp/initrd-crt.cpio

  if [ ! -s /boot/crt/initrd-crt.gz ]; then
    err_box "Failed to create initrd-crt.gz"
    cd /
    rm -rf "$workdir"
    exit 1
  fi

  # Clean up staging
  cd /
  rm -rf "$workdir"
  rm -f /boot/crt/initrd-src.gz

  ok_box "initrd-crt.gz created at /boot/crt/initrd-crt.gz"
}

deploy_crt_overlay_script() {
  local target="${CRT_SCRIPT_DIR}/batocera-save-crt-overlay"
  mkdir -p "$CRT_SCRIPT_DIR"

  cat > "$target" <<'OVERLAY_SCRIPT'
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

  chmod 755 "$target"
  ok_box "batocera-save-crt-overlay deployed to ${target}"
}

update_boot_config() {
  box_hash
  box_center "Updating boot configuration"
  box_hash
  box_empty

  remount_boot_rw

  # Batocera v44 uses syslinux for both EFI and Legacy BIOS boot.
  # Find all syslinux.cfg copies on the boot partition.
  local syslinux_files=""
  local f
  for f in /boot/EFI/batocera/syslinux.cfg \
           /boot/boot/syslinux.cfg \
           /boot/boot/syslinux/syslinux.cfg; do
    [ -f "$f" ] && syslinux_files="$syslinux_files $f"
  done

  if [ -z "$syslinux_files" ]; then
    err_box "No syslinux.cfg found on boot partition"
    exit 1
  fi

  local parent_dir
  for f in $syslinux_files; do
    parent_dir="$(basename "$(dirname "$f")")"

    if grep -q '^LABEL crt' "$f" 2>/dev/null; then
      box_center "CRT entry already in ${parent_dir}/syslinux.cfg — skipping"
    else
      # Rename existing menu labels for clarity
      sed -i 's/Batocera\.linux (\^normal)/Batocera HD - Wayland (^normal)/' "$f"
      sed -i 's/Batocera\.linux (\^verbose)/Batocera HD - Wayland (^verbose)/' "$f"

      # Append CRT boot entry
      cat >> "$f" <<'CRTSYSLINUX'

LABEL crt
	MENU LABEL Batocera CRT (X11)
	LINUX /crt/linux
	APPEND label=BATOCERA console=tty3 quiet loglevel=0 vt.global_cursor_default=0
	INITRD /crt/initrd-crt.gz
CRTSYSLINUX
      box_center "CRT entry added to ${parent_dir}/syslinux.cfg"
    fi

    # Set CRT as default for Phase 2 reboot (idempotent):
    # 1) Remove any existing MENU DEFAULT lines
    sed -i '/^[[:space:]]*MENU DEFAULT[[:space:]]*$/d' "$f"
    # 2) Add MENU DEFAULT under the CRT label
    sed -i '/^LABEL crt$/a\	MENU DEFAULT' "$f"
    # 3) Set DEFAULT directive for non-menu fallback
    if grep -q '^DEFAULT ' "$f"; then
      sed -i 's/^DEFAULT .*/DEFAULT crt/' "$f"
    else
      sed -i '1i\DEFAULT crt' "$f"
    fi
    box_center "Default set to CRT in ${parent_dir}/syslinux.cfg"
  done

  # Also update grub.cfg as fallback for removable-media EFI boot
  if [ -d /sys/firmware/efi ]; then
    local grub_cfg="/boot/EFI/BOOT/grub.cfg"
    if [ -f "$grub_cfg" ]; then
      if ! grep -q 'Batocera CRT (X11)' "$grub_cfg" 2>/dev/null; then
        sed -i 's/menuentry "Batocera\.linux (normal)"/menuentry "Batocera HD (Wayland)"/' "$grub_cfg"
        sed -i 's/menuentry "Batocera\.linux (verbose)"/menuentry "Batocera HD (verbose)"/' "$grub_cfg"
        sed -i 's/set timeout="1"/set timeout="3"/' "$grub_cfg"

        local insert_line
        insert_line=$(awk '/Batocera HD \(Wayland\)/{found=1} found && /^\}/{print NR; exit}' "$grub_cfg")
        if [ -n "$insert_line" ]; then
          sed -i "${insert_line}a\\
\\
menuentry \"Batocera CRT (X11)\" {\\
    echo Booting Batocera.linux... CRT Mode (X11)\\
    linux /crt/linux label=BATOCERA console=tty3 quiet loglevel=0 vt.global_cursor_default=0\\
    initrd /crt/initrd-crt.gz\\
}" "$grub_cfg"
        else
          cat >> "$grub_cfg" <<'CRTENTRY'

menuentry "Batocera CRT (X11)" {
    echo Booting Batocera.linux... CRT Mode (X11)
    linux /crt/linux label=BATOCERA console=tty3 quiet loglevel=0 vt.global_cursor_default=0
    initrd /crt/initrd-crt.gz
}
CRTENTRY
        fi
      fi
      sed -i 's/set default="0"/set default="1"/' "$grub_cfg"
      box_center "grub.cfg fallback also updated"
    fi
  fi

  # Remount read-only
  mount -o remount,ro /boot 2>/dev/null

  box_empty
  ok_box "Boot configuration updated (syslinux)"
}

prompt_cleanup_source_image() {
  local md5_file="${IMAGE_PATH}.md5"
  box_hash
  box_center "Cleanup"
  box_hash
  box_empty
  local fsize
  fsize=$(du -h "$IMAGE_PATH" 2>/dev/null | cut -f1)
  box_center "Source image: ${IMAGE_PATH}  (${fsize})"
  if [ -f "$md5_file" ]; then
    box_center "MD5 file:     ${md5_file}"
  fi
  box_empty
  box_center "The boot files have been extracted successfully."
  box_center "The source image is no longer needed."
  box_empty
  box_center "Delete it to free up space on /userdata/?"
  box_empty
  box_hash
  echo ""
  echo "  (1) Yes, delete it — reclaim ${fsize} on /userdata"
  echo "  (2) No, keep it — useful if you may need to reinstall later"
  echo ""
  read -r cleanup_choice
  if [ "$cleanup_choice" = "1" ]; then
    rm -f "$IMAGE_PATH"
    rm -f "$md5_file"
    ok_box "Source image and MD5 file deleted."
  else
    box_center "Source image kept at: ${IMAGE_PATH}"
  fi
}

run_phase1() {
  box_hash
  box_center "Dual-Boot Install — Phase 1 of 2"
  box_center "Setting up X11 boot environment alongside Wayland"
  box_hash
  echo ""
  sleep 1

  # The backup step already saved the HD monitor. Do not replace that list.
  if [ ! -s /userdata/Batocera-CRT-Script-Backup/mode_backups/hd_mode/video_settings/hd_mode_list.txt ]; then
    capture_hd_monitor_list
  fi

  # Step 1: Acquire image (scan local + download)
  prompt_image_source

  # Step 2: Validate checksum
  if ! validate_md5; then
    echo ""
    echo "  (1) Continue without MD5 verification"
    echo "  (2) Abort"
    echo ""
    read -r md5_choice
    case "$md5_choice" in
      1) echo "  Proceeding without checksum verification..." ;;
      *) exit 1 ;;
    esac
  fi

  # Step 3: Check disk space
  check_disk_space

  # Step 4: Extract boot files to /boot/crt/
  extract_x11_to_boot_crt

  # Step 5: Patch initrd for CRT boot path
  patch_initrd

  # Step 6: Update boot configuration (syslinux + grub.cfg fallback)
  update_boot_config

  # Step 7: Deploy CRT overlay save script
  deploy_crt_overlay_script

  # Step 8: Offer to delete source image
  prompt_cleanup_source_image

  # Step 9: Write phase flag for Phase 2
  mkdir -p "$(dirname "$PHASE_FLAG")"
  echo "2" > "$PHASE_FLAG"

  # Step 10: Phase 1 complete — show instructions and reboot
  echo ""
  box_hash
  box_center "${GREEN}${BOLD}Phase 1 Complete!${NOCOLOR}"
  box_hash
  box_empty
  box_center "The X11 boot environment is installed."
  box_center "Boot is configured to load X11 on next restart."
  box_empty
  box_center "WHAT HAPPENS NEXT:"
  box_empty
  box_center "1) System SHUTS DOWN."
  box_center "2) Press the POWER BUTTON to boot into X11."
  box_center "3) Re-run this CRT Script from X11."
  box_center "   It will detect Phase 2 automatically and continue"
  box_center "   with CRT display configuration."
  box_empty
  box_center "Your ROMs, saves, and BIOS files are shared."
  box_center "Nothing from your Wayland install is lost."
  box_empty
  box_hash
  box_empty
  box_center "${GREEN}${BOLD}Press ENTER to shut down...${NOCOLOR}"
  box_empty
  box_hash
  echo ""
  read -r
  _dualboot_installer_poweroff
}

########################################################################################
#####################    WAYLAND / X11 PHASE 1 FUNCTIONS END       ####################
########################################################################################

########################################################################################
#####################    WAYLAND / X11 DUAL-BOOT ROUTING START     ####################
########################################################################################

# Phase flag and script directory paths
PHASE_FLAG="/userdata/system/Batocera-CRT-Script/.install_phase"
CRT_SCRIPT_DIR="/userdata/system/Batocera-CRT-Script"

# Global state set by routing — consumed later in the script
IS_PHASE2=false
IS_DUALBOOT_INSTALL=false

detect_display_stack() {
  if [ -n "$(ls /run/user/*/wayland-* 2>/dev/null)" ] || pgrep -x labwc > /dev/null 2>&1; then
    DISPLAY_STACK="wayland"
  else
    DISPLAY_STACK="x11"
  fi
}

# Dual-boot Phase 1 / Phase 2: power off after installer prompts (not used for reboot).
# Matches Geometry_modeline/mode_switcher.sh: userspace poweroff can ACPI-hang on some
# desktops and Steam Deck; SysRq 'o' after overlay save + sync is reliable.
_dualboot_installer_poweroff() {
  batocera-save-overlay 2>/dev/null || true
  sync 2>/dev/null || true
  sync 2>/dev/null || true
  echo o > /proc/sysrq-trigger
}

# ── Entry-point routing ──
# Priority 1: Phase flag → Phase 2 (CRT config after reboot from Wayland Phase 1)
# Priority 2: Display stack detection → Wayland = Phase 1, X11 = standard install
if [ -f "$PHASE_FLAG" ] && [ "$(cat "$PHASE_FLAG" 2>/dev/null)" = "2" ]; then
  IS_PHASE2=true
  IS_DUALBOOT_INSTALL=true

  # Redirect the system's batocera-save-overlay so every save — explicit calls
  # in this script AND the automatic shutdown save — writes to /boot/crt/overlay
  # instead of /boot/boot/overlay.  Without this, CRT-specific binaries
  # (patched batocera-resolution, switchres.ini, etc.) contaminate the Wayland
  # overlay and break display detection on the next Wayland boot.
  if grep -q 'OVERLAYFILE="/boot/boot/overlay"' /usr/bin/batocera-save-overlay 2>/dev/null; then
    sed -i 's|OVERLAYFILE="/boot/boot/overlay"|OVERLAYFILE="/boot/crt/overlay"|' /usr/bin/batocera-save-overlay
  fi

  box_hash
  box_center "Resuming CRT Script — Phase 2 of 2"
  box_hash
  box_empty
  box_center "X11 detected. Dual-boot is already configured."
  box_center "Continuing with CRT display setup..."
  box_empty
  box_hash
  echo ""
  sleep 2
  # Fall through to backup_restore_main → standard CRT config flow
else
  detect_display_stack
  if [ "$DISPLAY_STACK" = "wayland" ]; then
    # If a backup exists, offer RESTORE before committing to Phase 1
    if [ -f "$CHECK_FILE" ]; then
      box_hash
      box_center "${BOLD}A previous installation was detected (Wayland)${NOCOLOR}"
      box_empty
      box_center "Run the dual-boot installer again (Press 1)"
      box_center "Restore to stock Batocera (Press 2)"
      box_empty
      box_center "Your games and save files will ${GREEN}NOT${NOCOLOR} be deleted."
      box_hash
      local wl_choice=""
      while :; do
        box_empty
        box_center "Your choice [1/2]:"
        box_empty
        if [ -e /dev/tty ]; then
          IFS= read -r wl_choice </dev/tty || wl_choice=""
        else
          IFS= read -r wl_choice || wl_choice=""
        fi
        wl_choice="${wl_choice:-1}"
        case "$wl_choice" in
          1) break ;;
          2) restore_all; exit 0 ;;
          *) box_center "Please enter 1 or 2." ;;
        esac
      done
    fi

    box_hash
    box_center "Wayland display stack detected."
    box_center "X11 is required for CRT mode."
    box_hash
    box_empty
    box_center "A second X11 Batocera boot entry will be set up"
    box_center "alongside your existing Wayland install."
    box_center "Your ROMs, saves, and BIOS files will be shared."
    box_empty
    box_hash
    echo ""
    sleep 2
    run_phase1
    exit 0
  fi
  # DISPLAY_STACK=x11 → fall through to standard CRT install
fi

########################################################################################
#####################    WAYLAND / X11 DUAL-BOOT ROUTING END       ####################
########################################################################################

# >>> Call the backup/restore entry-point now, then continue with the rest of the script:
backup_restore_main || exit 1
########################################################################################
#####################                 BACKUP EXIST END		   		   #################
########################################################################################
