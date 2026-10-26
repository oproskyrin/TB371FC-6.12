#!/bin/sh
# Read-only microSD inspection from the first-stage 4.19 console.
uname -r
mnt=/mnt/r156-sd
mkdir -p $mnt
mountpoint -q $mnt || mount -t exfat -o rw,noatime /dev/mmcblk0p1 $mnt
ls -la $mnt/tb371fc-linux/
ls -la $mnt/tb371fc-linux/persist 2>&1
df -h $mnt | tail -1
dmesg | grep -i -E "mmc0|mmcblk|exfat|I/O error" | tail -10
umount $mnt
