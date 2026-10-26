#!/bin/sh
# R166 diagnostic: memory map snapshot, then memtester pinned to ONE cpu ($CPU, default 0) with
# optional policy max cap ($CAP kHz for the policy owning that cpu). Marker lines go to kmsg.
CPU=${CPU:-0}; CAP=${CAP:-}
echo 0 > /proc/sys/kernel/panic_on_oops
grep -E "System RAM|reserved" /proc/iomem > /run/iomem.txt; head -40 /run/iomem.txt
for m in /proc/device-tree/memory*; do echo "$m: $(od -An -tx4 $m/reg | tr -s ' ')"; done
p=$(dirname $(readlink -f /sys/devices/system/cpu/cpu$CPU/cpufreq))/$(basename $(readlink -f /sys/devices/system/cpu/cpu$CPU/cpufreq))
[ -n "$CAP" ] && echo $CAP > $p/scaling_max_freq
echo "cpu=$CPU policy=$(basename $p) max=$(cat $p/scaling_max_freq)"
echo "== MEMTEST cpu$CPU cap=${CAP:-none} start" > /dev/kmsg
taskset -c $CPU memtester 4G 1 2>&1 | tr '\b' '\n' | grep -E "Loop|ok|FAIL|failure|Done|error" | uniq
echo "== MEMTEST cpu$CPU end rc=$?" > /dev/kmsg; echo done
