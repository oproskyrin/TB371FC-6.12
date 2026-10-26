#!/bin/sh
# R174: finish mkupper after the serial session dropped (dd had completed): sync, rename, check.
set -u
d=/mnt/r174-sd/tb371fc-linux/persist
[ "$(stat -c %s $d/upper.img.partial)" = 17179869184 ] || { echo "size mismatch"; exit 1; }
sync; mv $d/upper.img.partial $d/upper.img; sync
ls -la $d; umount /mnt/r174-sd
/run/fsck.exfat -n /dev/mmcblk0p1; echo "fsck rc=$?"
echo MKUPPER_OK
