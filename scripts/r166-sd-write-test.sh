#!/bin/sh
# R166 test: is microSD writing stable from 6.12 now that the kexec RAM hole is reserved?
# Writes SIZE_MB of zeros to tb371fc-linux/sdtest/test.bin (fsync), drops caches, re-reads and
# compares the hash, removes the file and returns the exFAT mount to read-only.
set -u
SIZE_MB=1024
sd=/run/r129/sd; d=$sd/tb371fc-linux/sdtest
echo 0 > /proc/sys/kernel/panic_on_oops
grep " $sd " /proc/mounts
blockdev --setrw /dev/mmcblk0; blockdev --setrw /dev/mmcblk0p1
mount -o remount,rw $sd || { echo "remount rw failed"; blockdev --setro /dev/mmcblk0p1; blockdev --setro /dev/mmcblk0; exit 1; }
mkdir -p $d
echo "== SDTEST write ${SIZE_MB}M start" > /dev/kmsg
t0=$(cut -d' ' -f1 /proc/uptime)
dd if=/dev/zero of=$d/test.bin bs=4M count=$((SIZE_MB/4)) conv=fsync 2>&1 | tail -1
t1=$(cut -d' ' -f1 /proc/uptime)
echo "== SDTEST write done" > /dev/kmsg
sync; echo 3 > /proc/sys/vm/drop_caches
want=$(head -c $((SIZE_MB*1024*1024)) /dev/zero | sha256sum | cut -d' ' -f1)
got=$(sha256sum $d/test.bin | cut -d' ' -f1)
t2=$(cut -d' ' -f1 /proc/uptime)
echo "write ${SIZE_MB}M: $(echo "$t0 $t1" | awk '{printf "%.1f s", $2-$1}'), read+hash: $(echo "$t1 $t2" | awk '{printf "%.1f s", $2-$1}')"
[ "$want" = "$got" ] && echo "SDTEST HASH OK" || echo "SDTEST HASH MISMATCH"
rm -f $d/test.bin; rmdir $d; sync
mount -o remount,ro $sd; blockdev --setro /dev/mmcblk0p1; blockdev --setro /dev/mmcblk0; grep " $sd " /proc/mounts; cat /sys/block/mmcblk0/ro
dmesg | grep -i -E "mmc|sdhci|exfat|I/O error" | tail -8
