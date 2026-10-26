#!/bin/sh
# R187 (first-stage 4.19 console): mount the microSD exFAT rw at /mnt/r187-sd, write the payload to
# the NEW folder tb371fc-linux/autoboot-6.12-r187 and
# verify it by reading back. No other file on the card is touched.
set -eu
bb=/run/tb371fc-rescue/busybox
src=/run/r187-src; dst_rel=tb371fc-linux/autoboot-6.12-r187; mnt=/mnt/r187-sd
[ "$(uname -r)" = 4.19.157-perf-v56.6+ ]
mkdir -p "$src"; "$bb" tar -xzf /run/tb371fc-r187.tar.gz -C "$src"
check() { [ "$("$bb" sha256sum "$1" | "$bb" awk '{print $1}')" = "$2" ] || { echo "HASH FAIL $1"; exit 1; }; }
check "$src/Image" 2d412d9b57a184a5c4a516e1e72133aff0717700efed5617f72631b953832f77
check "$src/board.dtb" a02916b971a9930c57da05485ef8e1ea63e0e669832286d11e17d8b0603cb79d
check "$src/initramfs.cpio.gz" d0c2418e252e75bcbc46481988dce0199f55e2be4ed7ef3a1b48a88fb19b86b1
mkdir -p "$mnt"
mountpoint -q "$mnt" || mount -t exfat -o rw,noatime /dev/mmcblk0p1 "$mnt"
[ -f "$mnt/tb371fc-linux/tb371fc-arch-development.raw" ]
df -h "$mnt" | tail -1
mkdir -p "$mnt/$dst_rel" "$mnt/tb371fc-linux/layers"
for f in Image board.dtb initramfs.cpio.gz; do cp "$src/$f" "$mnt/$dst_rel/$f.partial"; mv "$mnt/$dst_rel/$f.partial" "$mnt/$dst_rel/$f"; done
(cd "$src"; "$bb" sha256sum Image board.dtb initramfs.cpio.gz) > "$mnt/$dst_rel/SHA256SUMS"
sync; echo 3 > /proc/sys/vm/drop_caches
check "$mnt/$dst_rel/Image" 2d412d9b57a184a5c4a516e1e72133aff0717700efed5617f72631b953832f77
check "$mnt/$dst_rel/board.dtb" a02916b971a9930c57da05485ef8e1ea63e0e669832286d11e17d8b0603cb79d
check "$mnt/$dst_rel/initramfs.cpio.gz" d0c2418e252e75bcbc46481988dce0199f55e2be4ed7ef3a1b48a88fb19b86b1
ls -la "$mnt/$dst_rel"
printf "R187 autoboot payload, installed %s. Delete this ENABLE file to disable autoboot.
" "$(date)" > "$mnt/$dst_rel/ENABLE"
[ -f "$mnt/tb371fc-linux/layers/r163-apps.img" ] && echo "apps layer present"
[ -f "$mnt/tb371fc-linux/layers/r171-apps.img" ] && echo "r171 layer present"
sync; ls -la "$mnt/$dst_rel"; umount "$mnt"
echo SD_INSTALL_OK
