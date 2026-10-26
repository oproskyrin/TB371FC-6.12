#!/bin/sh
# R178: microSD speed under the Lenovo 4.19 kernel (SDR104 with BH201 tuning): the card's real limit.
cat /sys/kernel/debug/mmc0/ios 2>/dev/null | grep -E "^(clock|timing|signal)"
sync; echo 3 > /proc/sys/vm/drop_caches
dd if=/dev/mmcblk0p2 of=/dev/null bs=4M count=128 skip=500 iflag=direct 2>&1 | tail -1
dd if=/dev/zero of=/var/tmp/r178-w.bin bs=4M count=64 oflag=direct 2>&1 | tail -1
rm -f /var/tmp/r178-w.bin; sync
