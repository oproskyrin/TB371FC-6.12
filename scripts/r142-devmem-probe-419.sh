#!/bin/sh
# Read-only check: can 4.19 read the 0x9e300000 reserved region via /dev/mem?
[ -e /run/mem ] || /run/tb371fc-rescue/busybox mknod /run/mem c 1 1; ls -l /run/mem
find /proc/device-tree/reserved-memory -maxdepth 1 | grep -i -E "9e3|dfps|splash|cont"
for d in /proc/device-tree/reserved-memory/*9e3*; do [ -d "$d" ] && { echo "$d"; ls "$d"; od -An -tx4 --endian=big "$d/reg"; }; done
bb=/run/tb371fc-rescue/busybox
$bb dd if=/run/mem bs=4096 skip=$((0x9e300000/4096)) count=1 2>&1 | $bb hexdump -C | head -8
$bb dd if=/run/mem bs=4096 skip=$((0x9e380000/4096)) count=1 2>&1 | $bb hexdump -C | head -6
