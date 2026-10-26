#!/bin/sh
# R166 recon (4.19 console, read-only): who owns RAM around 0x1d0000000 (hangs 6.12 on read).
cat /sys/devices/system/memory/block_size_bytes 2>&1
for b in /sys/devices/system/memory/memory*; do
  n=${b##*memory}; echo "$n $(cat $b/state 2>/dev/null) $(cat $b/removable 2>/dev/null)"
done | sort -n | awk '{printf "%s:%s ", $1, $2} END {print ""}'
echo "--- iomem nested 0x1c0000000-0x1ffffffff"
awk -F' : ' '{split($1,a,"-"); if (length(a[1])>=9) print}' /proc/iomem | grep -i -E "^ *1[c-f]|^ *ffc2" | head -30
echo "--- dmesg memory hotplug / offline / ddr"
dmesg | grep -i -E "mem-offline|mem_offline|memory block|hotplug|online|offline|ddr|rank|partial" | head -30
ls /sys/kernel/mem-offline 2>/dev/null; cat /sys/kernel/mem-offline/* 2>/dev/null | head
for n in /proc/device-tree/mem-offline /proc/device-tree/soc/mem-offline*; do [ -e $n ] && { echo "== $n"; ls $n; }; done
grep -l -r "mem-offline" /proc/device-tree/compatible 2>/dev/null
find /proc/device-tree -maxdepth 2 -name "*offline*" 2>/dev/null
