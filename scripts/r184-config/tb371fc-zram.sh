#!/bin/sh
# zram swap: half of the RAM, lzo-rle (the only zram backend built into the R179 kernel)
set -e
[ -e /dev/zram0 ] || { [ -e /sys/class/zram-control/hot_add ] && cat /sys/class/zram-control/hot_add >/dev/null; }
swapoff /dev/zram0 2>/dev/null || true
echo 1 > /sys/block/zram0/reset 2>/dev/null || true
kb=$(awk '/MemTotal/{print $2}' /proc/meminfo)
echo lzo-rle > /sys/block/zram0/comp_algorithm
echo $((kb / 2 * 1024)) > /sys/block/zram0/disksize
mkswap -q /dev/zram0
swapon -p 100 /dev/zram0
