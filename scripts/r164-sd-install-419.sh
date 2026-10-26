#!/bin/sh
# R164 (first-stage 4.19 console): mount the microSD exFAT rw at /mnt/r164-sd (kept mounted for
# the layer upload), write the payload to the NEW folder tb371fc-linux/autoboot-6.12-r164 and
# verify it by reading back. No other file on the card is touched.
set -eu
bb=/run/tb371fc-rescue/busybox
src=/run/r164-src; dst_rel=tb371fc-linux/autoboot-6.12-r164; mnt=/mnt/r164-sd
[ "$(uname -r)" = 4.19.157-perf-v56.6+ ]
mkdir -p "$src"; "$bb" tar -xzf /run/tb371fc-r164.tar.gz -C "$src"
check() { [ "$("$bb" sha256sum "$1" | "$bb" awk '{print $1}')" = "$2" ] || { echo "HASH FAIL $1"; exit 1; }; }
check "$src/Image" 62763187b5dc1958419462a83bbd2f0cc9fa19f31bf0e3700cd1167314172dac
check "$src/board.dtb" 49c42b852bdb93e6e001248fce82290dcf19f9f67cbdc1a828ec2b58eecdc680
check "$src/initramfs.cpio.gz" d6f308bcc280a2a13ca234f297768c7d526223938b88ce8b99aca0133606bd0d
mkdir -p "$mnt"
mountpoint -q "$mnt" || mount -t exfat -o rw,noatime /dev/mmcblk0p1 "$mnt"
[ -f "$mnt/tb371fc-linux/tb371fc-arch-development.raw" ]
df -h "$mnt" | tail -1
mkdir -p "$mnt/$dst_rel" "$mnt/tb371fc-linux/layers"
for f in Image board.dtb initramfs.cpio.gz; do cp "$src/$f" "$mnt/$dst_rel/$f.partial"; mv "$mnt/$dst_rel/$f.partial" "$mnt/$dst_rel/$f"; done
(cd "$src"; "$bb" sha256sum Image board.dtb initramfs.cpio.gz) > "$mnt/$dst_rel/SHA256SUMS"
sync; echo 3 > /proc/sys/vm/drop_caches
check "$mnt/$dst_rel/Image" 62763187b5dc1958419462a83bbd2f0cc9fa19f31bf0e3700cd1167314172dac
check "$mnt/$dst_rel/board.dtb" 49c42b852bdb93e6e001248fce82290dcf19f9f67cbdc1a828ec2b58eecdc680
check "$mnt/$dst_rel/initramfs.cpio.gz" d6f308bcc280a2a13ca234f297768c7d526223938b88ce8b99aca0133606bd0d
ls -la "$mnt/$dst_rel"
printf "R164 autoboot payload, installed %s. Delete this ENABLE file to disable autoboot.
" "$(date)" > "$mnt/$dst_rel/ENABLE"
[ -f "$mnt/tb371fc-linux/layers/r163-apps.img" ] && echo "apps layer present"
sync; ls -la "$mnt/$dst_rel"; umount "$mnt"
echo SD_INSTALL_OK
