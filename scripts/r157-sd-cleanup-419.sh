#!/bin/sh
# Remove the empty leftovers of the failed R154-R156 persist attempts (4.19 console).
set -eu
mnt=/mnt/r157-sd
mkdir -p $mnt
mountpoint -q $mnt || mount -t exfat -o rw,noatime /dev/mmcblk0p1 $mnt
d=$mnt/tb371fc-linux/persist
if [ -d "$d" ]; then
    ls -la "$d"
    [ ! -s "$d/upper.img.partial" ] && rm -f "$d/upper.img.partial"
    [ -e "$d/upper.img" ] && echo "upper.img present, leaving it" || rmdir "$d"
fi
sync
ls -la $mnt/tb371fc-linux/
umount $mnt
