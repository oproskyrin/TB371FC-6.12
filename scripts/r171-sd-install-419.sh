#!/bin/sh
# R171 (first-stage 4.19 console): mount the microSD exFAT rw at /mnt/r171-sd (kept mounted for
# the layer upload), write the payload to the NEW folder tb371fc-linux/autoboot-6.12-r171 and
# verify it by reading back. No other file on the card is touched.
set -eu
bb=/run/tb371fc-rescue/busybox
src=/run/r171-src; dst_rel=tb371fc-linux/autoboot-6.12-r171; mnt=/mnt/r171-sd
[ "$(uname -r)" = 4.19.157-perf-v56.6+ ]
mkdir -p "$src"; "$bb" tar -xzf /run/tb371fc-r171.tar.gz -C "$src"
check() { [ "$("$bb" sha256sum "$1" | "$bb" awk '{print $1}')" = "$2" ] || { echo "HASH FAIL $1"; exit 1; }; }
check "$src/Image" 62763187b5dc1958419462a83bbd2f0cc9fa19f31bf0e3700cd1167314172dac
check "$src/board.dtb" d341922a8ee8393b95637933751f1ea5584bb9659bed3ea32ebcb85818876ca2
check "$src/initramfs.cpio.gz" bb9753ee6a3c18e95c9b12190ccfd7b04c0ff5d4c81134b3bf5c79cb2f226229
mkdir -p "$mnt"
mountpoint -q "$mnt" || mount -t exfat -o rw,noatime /dev/mmcblk0p1 "$mnt"
[ -f "$mnt/tb371fc-linux/tb371fc-arch-development.raw" ]
df -h "$mnt" | tail -1
mkdir -p "$mnt/$dst_rel" "$mnt/tb371fc-linux/layers"
for f in Image board.dtb initramfs.cpio.gz; do cp "$src/$f" "$mnt/$dst_rel/$f.partial"; mv "$mnt/$dst_rel/$f.partial" "$mnt/$dst_rel/$f"; done
(cd "$src"; "$bb" sha256sum Image board.dtb initramfs.cpio.gz) > "$mnt/$dst_rel/SHA256SUMS"
sync; echo 3 > /proc/sys/vm/drop_caches
check "$mnt/$dst_rel/Image" 62763187b5dc1958419462a83bbd2f0cc9fa19f31bf0e3700cd1167314172dac
check "$mnt/$dst_rel/board.dtb" d341922a8ee8393b95637933751f1ea5584bb9659bed3ea32ebcb85818876ca2
check "$mnt/$dst_rel/initramfs.cpio.gz" bb9753ee6a3c18e95c9b12190ccfd7b04c0ff5d4c81134b3bf5c79cb2f226229
ls -la "$mnt/$dst_rel"
printf "R171 autoboot payload, installed %s. Delete this ENABLE file to disable autoboot.
" "$(date)" > "$mnt/$dst_rel/ENABLE"
[ -f "$mnt/tb371fc-linux/layers/r163-apps.img" ] && echo "apps layer present"
# R171: bluedevil layer (uploaded to /run/r171-apps.img by the PC)
l=$mnt/tb371fc-linux/layers/r171-apps.img
check /run/r171-apps.img 7e26fa2b4d6809f5daa423f52e14ca8b2b6af101ccc620f05a45a97a4b33044d
cp /run/r171-apps.img "$l.partial"; mv "$l.partial" "$l"; sync; echo 3 > /proc/sys/vm/drop_caches
check "$l" 7e26fa2b4d6809f5daa423f52e14ca8b2b6af101ccc620f05a45a97a4b33044d && echo "r171 layer written"
sync; ls -la "$mnt/$dst_rel"; umount "$mnt"
echo SD_INSTALL_OK
