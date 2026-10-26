#!/bin/sh
# R174 (first-stage 4.19 console): repair the microSD exFAT after the 6.12 write tests. The only
# fault fsck found: test file sdtest612/d1.bin shares a cluster with its directory (the directory
# cluster was not yet marked in the bitmap when 6.12 rebooted). fsck -y, remove the test folder,
# check again. Nothing else on the card is touched.
set -u
bb=/run/tb371fc-rescue/busybox; f=/run/fsck.exfat
[ "$(uname -r)" = 4.19.157-perf-v56.6+ ] || { echo "not 4.19"; exit 1; }
chmod +x $f
[ "$("$bb" sha256sum $f | "$bb" awk '{print $1}')" = 9db479760361ac0671b18c2447af59b02e3c7948656e7e7bd0bb0b5484c048d9 ] || { echo "fsck hash"; exit 1; }
grep mmcblk0p1 /proc/mounts && { for m in $(grep mmcblk0p1 /proc/mounts | "$bb" awk '{print $2}'); do umount "$m"; done; }
grep -q mmcblk0p1 /proc/mounts && { echo "still mounted"; exit 1; }
echo "== fsck -y"; $f -y /dev/mmcblk0p1; echo "rc=$?"
m=/mnt/r174-sd; mkdir -p $m
mount -t exfat -o rw,noatime /dev/mmcblk0p1 $m && ls -la $m/tb371fc-linux/sdtest612/ && rm -rf $m/tb371fc-linux/sdtest612 && echo "test folder removed"
sync; umount $m
echo "== fsck -n"; $f -n /dev/mmcblk0p1; echo "rc=$?"
echo FSCK_DONE
