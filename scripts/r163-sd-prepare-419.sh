#!/bin/sh
# R163 (first-stage 4.19 console): mount the microSD exFAT rw at /mnt/r163-sd (kept mounted for
# the layer upload), write the payload to the NEW folder tb371fc-linux/autoboot-6.12-r163 and
# verify it by reading back. No other file on the card is touched.
set -eu
bb=/run/tb371fc-rescue/busybox
src=/run/r163-src; dst_rel=tb371fc-linux/autoboot-6.12-r163; mnt=/mnt/r163-sd
[ "$(uname -r)" = 4.19.157-perf-v56.6+ ]
mkdir -p "$src"; "$bb" tar -xzf /run/tb371fc-r163.tar.gz -C "$src"
check() { [ "$("$bb" sha256sum "$1" | "$bb" awk '{print $1}')" = "$2" ] || { echo "HASH FAIL $1"; exit 1; }; }
check "$src/Image" 62763187b5dc1958419462a83bbd2f0cc9fa19f31bf0e3700cd1167314172dac
check "$src/board.dtb" 3ddc9d5856c9cd559752a3753190922fef0bafe3fc27694f57b0e16cf710c221
check "$src/initramfs.cpio.gz" 56264a181e9d0e733bcb8017e2ad206131be909397e2bd0d70935065c2e33d98
mkdir -p "$mnt"
mountpoint -q "$mnt" || mount -t exfat -o rw,noatime /dev/mmcblk0p1 "$mnt"
[ -f "$mnt/tb371fc-linux/tb371fc-arch-development.raw" ]
df -h "$mnt" | tail -1
mkdir -p "$mnt/$dst_rel" "$mnt/tb371fc-linux/layers"
for f in Image board.dtb initramfs.cpio.gz; do cp "$src/$f" "$mnt/$dst_rel/$f.partial"; mv "$mnt/$dst_rel/$f.partial" "$mnt/$dst_rel/$f"; done
(cd "$src"; "$bb" sha256sum Image board.dtb initramfs.cpio.gz) > "$mnt/$dst_rel/SHA256SUMS"
sync; echo 3 > /proc/sys/vm/drop_caches
check "$mnt/$dst_rel/Image" 62763187b5dc1958419462a83bbd2f0cc9fa19f31bf0e3700cd1167314172dac
check "$mnt/$dst_rel/board.dtb" 3ddc9d5856c9cd559752a3753190922fef0bafe3fc27694f57b0e16cf710c221
check "$mnt/$dst_rel/initramfs.cpio.gz" 56264a181e9d0e733bcb8017e2ad206131be909397e2bd0d70935065c2e33d98
rm -f "$mnt/tb371fc-linux/layers/r163-apps.img.partial"
ls -la "$mnt/$dst_rel"
echo SD_PAYLOAD_OK
