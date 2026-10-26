#!/bin/sh
# R170 (first-stage 4.19 console): mount the microSD exFAT rw at /mnt/r170-sd (kept mounted for
# the layer upload), write the payload to the NEW folder tb371fc-linux/autoboot-6.12-r170 and
# verify it by reading back. No other file on the card is touched.
set -eu
bb=/run/tb371fc-rescue/busybox
src=/run/r170-src; dst_rel=tb371fc-linux/autoboot-6.12-r170; mnt=/mnt/r170-sd
[ "$(uname -r)" = 4.19.157-perf-v56.6+ ]
mkdir -p "$src"; "$bb" tar -xzf /run/tb371fc-r170.tar.gz -C "$src"
check() { [ "$("$bb" sha256sum "$1" | "$bb" awk '{print $1}')" = "$2" ] || { echo "HASH FAIL $1"; exit 1; }; }
check "$src/Image" 62763187b5dc1958419462a83bbd2f0cc9fa19f31bf0e3700cd1167314172dac
check "$src/board.dtb" a99cb12414292f886bd30f2ab31652ed8d92996d2224cfbd4d36dc43e2888655
check "$src/initramfs.cpio.gz" c8b91978b2fd3e5bdfff8d358bd0646b15556f89d366139a3fb059ac42f67d3e
mkdir -p "$mnt"
mountpoint -q "$mnt" || mount -t exfat -o rw,noatime /dev/mmcblk0p1 "$mnt"
[ -f "$mnt/tb371fc-linux/tb371fc-arch-development.raw" ]
df -h "$mnt" | tail -1
mkdir -p "$mnt/$dst_rel" "$mnt/tb371fc-linux/layers"
for f in Image board.dtb initramfs.cpio.gz; do cp "$src/$f" "$mnt/$dst_rel/$f.partial"; mv "$mnt/$dst_rel/$f.partial" "$mnt/$dst_rel/$f"; done
(cd "$src"; "$bb" sha256sum Image board.dtb initramfs.cpio.gz) > "$mnt/$dst_rel/SHA256SUMS"
sync; echo 3 > /proc/sys/vm/drop_caches
check "$mnt/$dst_rel/Image" 62763187b5dc1958419462a83bbd2f0cc9fa19f31bf0e3700cd1167314172dac
check "$mnt/$dst_rel/board.dtb" a99cb12414292f886bd30f2ab31652ed8d92996d2224cfbd4d36dc43e2888655
check "$mnt/$dst_rel/initramfs.cpio.gz" c8b91978b2fd3e5bdfff8d358bd0646b15556f89d366139a3fb059ac42f67d3e
ls -la "$mnt/$dst_rel"
printf "R170 autoboot payload, installed %s. Delete this ENABLE file to disable autoboot.
" "$(date)" > "$mnt/$dst_rel/ENABLE"
[ -f "$mnt/tb371fc-linux/layers/r163-apps.img" ] && echo "apps layer present"
sync; ls -la "$mnt/$dst_rel"; umount "$mnt"
echo SD_INSTALL_OK
