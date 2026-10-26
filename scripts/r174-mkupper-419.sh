#!/bin/sh
# R174 (first-stage 4.19 console): create the persistent overlay file tb371fc-linux/persist/upper.img
# (16 GiB of zeros) on the microSD exFAT. Fixed size: later 6.12 only rewrites data inside it, so
# the exFAT metadata never changes at runtime. mkfs.ext4 is done from 6.12 (inside the file).
set -eu
bb=/run/tb371fc-rescue/busybox
[ "$(uname -r)" = 4.19.157-perf-v56.6+ ]
m=/mnt/r174-sd; mkdir -p $m
mountpoint -q $m || mount -t exfat -o rw,noatime /dev/mmcblk0p1 $m
[ -f $m/tb371fc-linux/tb371fc-arch-development.raw ]
df -h $m | tail -1
d=$m/tb371fc-linux/persist; mkdir -p $d
if [ -f $d/upper.img ]; then echo "upper.img exists"; ls -la $d; umount $m; echo MKUPPER_OK; exit 0; fi
t0=$("$bb" date +%s)
"$bb" dd if=/dev/zero of=$d/upper.img.partial bs=1048576 count=16384 2>&1 | tail -1
sync
mv $d/upper.img.partial $d/upper.img
t1=$("$bb" date +%s)
echo "16 GiB written in $((t1-t0)) s"
ls -la $d; sync; umount $m
"$bb" test -x /run/fsck.exfat && /run/fsck.exfat -n /dev/mmcblk0p1
echo MKUPPER_OK
