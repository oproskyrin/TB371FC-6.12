#!/bin/sh
# R154: create the persistent overlay upper image on the microSD (new file only).
set -eu
sd=/run/r129/sd
dir=$sd/tb371fc-linux/persist
img=$dir/upper.img
[ -f "$sd/tb371fc-linux/tb371fc-arch-development.raw" ]
blockdev --setrw /dev/mmcblk0 /dev/mmcblk0p1
mount -o remount,rw "$sd"
trap 'sync; mount -o remount,ro "$sd" || true; blockdev --setro /dev/mmcblk0p1 /dev/mmcblk0 || true; lsblk -o NAME,RO /dev/mmcblk0' EXIT
[ -e /proc/device-tree/soc@0/mmc@8804000/non-removable ] || { echo "SD is not non-removable; refusing"; exit 1; }
mkdir -p "$dir"
rm -f "$img.partial"
if [ -e "$img" ]; then echo "exists: $(ls -la "$img")"; exit 0; fi
t0=$(cut -d' ' -f1 /proc/uptime)
truncate -s 16G "$img.partial"
mkfs.ext4 -q -F -L tb371fc-persist -E lazy_itable_init=1,lazy_journal_init=1 "$img.partial"
sync
mv "$img.partial" "$img"
sync
echo "created in $(echo "$(cut -d' ' -f1 /proc/uptime) - $t0" | bc 2>/dev/null || true) s"
ls -la "$dir"
dmesg | grep -i -E "mmc0|I/O error|exfat" | tail -5
dumpe2fs -h "$img" 2>/dev/null | grep -E "Filesystem volume name|Block count|Filesystem state"
df -h "$sd" | tail -1
