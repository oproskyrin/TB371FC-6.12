#!/bin/sh
# Runs in the first-stage 4.19 console. Writes the R149b payload into a NEW
# microSD folder tb371fc-linux/autoboot-6.12 (no other file on the card is
# touched), then verifies every file by reading it back from the card.
set -eu
bb=/run/tb371fc-rescue/busybox
src=/run/r150-src
dst_rel=tb371fc-linux/autoboot-6.12
mnt=/mnt/r150-sd
[ "$(uname -r)" = 4.19.157-perf-v56.6+ ]
mkdir -p "$src"
"$bb" tar -xzf /run/tb371fc-r149b.tar.gz -C "$src"
check() { [ "$("$bb" sha256sum "$1" | "$bb" awk '{print $1}')" = "$2" ] || { echo "HASH FAIL $1"; exit 1; }; }
check "$src/Image" 03b2f15272040962984d70f77356b9686429f0b7024d85ed8fa4150b6129ec61
check "$src/board.dtb" b1dd3d85e6b67905aab46d33177461c100a7347399cdaad7cb63dd317ca66a0f
check "$src/initramfs.cpio.gz" c16e279bb110f9cfa8f3ed1fd79a430d78d0904f024c81d03cbe9be2681aa4fc
mkdir -p "$mnt"
mountpoint -q "$mnt" || mount -t exfat -o rw,noatime /dev/mmcblk0p1 "$mnt"
[ -f "$mnt/tb371fc-linux/tb371fc-arch-development.raw" ]   # right card
df -h "$mnt" | tail -1
[ ! -e "$mnt/$dst_rel" ] || { echo "already exists: $dst_rel"; ls -la "$mnt/$dst_rel"; }
mkdir -p "$mnt/$dst_rel"
for f in Image board.dtb initramfs.cpio.gz; do
	cp "$src/$f" "$mnt/$dst_rel/$f.partial"
	mv "$mnt/$dst_rel/$f.partial" "$mnt/$dst_rel/$f"
done
(cd "$src"; "$bb" sha256sum Image board.dtb initramfs.cpio.gz) > "$mnt/$dst_rel/SHA256SUMS"
printf 'R149b autoboot payload, installed %s. Delete this ENABLE file to disable autoboot.\n' "$(date)" > "$mnt/$dst_rel/ENABLE"
sync
echo 3 > /proc/sys/vm/drop_caches
check "$mnt/$dst_rel/Image" 03b2f15272040962984d70f77356b9686429f0b7024d85ed8fa4150b6129ec61
check "$mnt/$dst_rel/board.dtb" b1dd3d85e6b67905aab46d33177461c100a7347399cdaad7cb63dd317ca66a0f
check "$mnt/$dst_rel/initramfs.cpio.gz" c16e279bb110f9cfa8f3ed1fd79a430d78d0904f024c81d03cbe9be2681aa4fc
ls -la "$mnt/$dst_rel"
umount "$mnt"
echo SD_INSTALL_OK
