#!/bin/sh
# R184 (first-stage 4.19 console): mount the microSD exFAT rw at /mnt/r184-sd, write the payload to
# the NEW folder tb371fc-linux/autoboot-6.12-r184 and
# verify it by reading back. No other file on the card is touched.
set -eu
bb=/run/tb371fc-rescue/busybox
src=/run/r184-src; dst_rel=tb371fc-linux/autoboot-6.12-r184; mnt=/mnt/r184-sd
[ "$(uname -r)" = 4.19.157-perf-v56.6+ ]
mkdir -p "$src"; "$bb" tar -xzf /run/tb371fc-r184.tar.gz -C "$src"
check() { [ "$("$bb" sha256sum "$1" | "$bb" awk '{print $1}')" = "$2" ] || { echo "HASH FAIL $1"; exit 1; }; }
check "$src/Image" 55fcf49e30a4abbe564cc17e255e107947346c7895016e2eb200011fdd117c0d
check "$src/board.dtb" 33eaf41be0dda8c77f5c465a7e521aeade1dd9830563bade7535c49f5689f1b4
check "$src/initramfs.cpio.gz" 291258e8d4dd2e16b343988a7df9565555c03dd9e12ff1ce198d641a83d4db3a
mkdir -p "$mnt"
mountpoint -q "$mnt" || mount -t exfat -o rw,noatime /dev/mmcblk0p1 "$mnt"
[ -f "$mnt/tb371fc-linux/tb371fc-arch-development.raw" ]
df -h "$mnt" | tail -1
mkdir -p "$mnt/$dst_rel" "$mnt/tb371fc-linux/layers"
for f in Image board.dtb initramfs.cpio.gz; do cp "$src/$f" "$mnt/$dst_rel/$f.partial"; mv "$mnt/$dst_rel/$f.partial" "$mnt/$dst_rel/$f"; done
(cd "$src"; "$bb" sha256sum Image board.dtb initramfs.cpio.gz) > "$mnt/$dst_rel/SHA256SUMS"
sync; echo 3 > /proc/sys/vm/drop_caches
check "$mnt/$dst_rel/Image" 55fcf49e30a4abbe564cc17e255e107947346c7895016e2eb200011fdd117c0d
check "$mnt/$dst_rel/board.dtb" 33eaf41be0dda8c77f5c465a7e521aeade1dd9830563bade7535c49f5689f1b4
check "$mnt/$dst_rel/initramfs.cpio.gz" 291258e8d4dd2e16b343988a7df9565555c03dd9e12ff1ce198d641a83d4db3a
ls -la "$mnt/$dst_rel"
printf "R184 autoboot payload, installed %s. Delete this ENABLE file to disable autoboot.
" "$(date)" > "$mnt/$dst_rel/ENABLE"
[ -f "$mnt/tb371fc-linux/layers/r163-apps.img" ] && echo "apps layer present"
[ -f "$mnt/tb371fc-linux/layers/r171-apps.img" ] && echo "r171 layer present"
sync; ls -la "$mnt/$dst_rel"; umount "$mnt"
echo SD_INSTALL_OK
