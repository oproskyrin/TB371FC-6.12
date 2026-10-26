#!/bin/sh
# R166 diagnostic: disable every cpuidle state deeper than WFI on all CPUs at runtime, list what
# was disabled, then run the same unpinned memtester (3G) that hung before.
echo 0 > /proc/sys/kernel/panic_on_oops
for s in /sys/devices/system/cpu/cpu*/cpuidle/state*; do
	n=${s##*state}; [ "$n" = 0 ] && continue
	echo 1 > $s/disable
done
for s in /sys/devices/system/cpu/cpu0/cpuidle/state* /sys/devices/system/cpu/cpu7/cpuidle/state*; do echo "$s $(cat $s/name) disable=$(cat $s/disable) usage=$(cat $s/usage)"; done
ls /sys/kernel/debug/pm_genpd 2>/dev/null | head -3
echo "== MEMTEST noidle start" > /dev/kmsg
memtester 3G 1 2>&1 | tr '\b' '\n' | grep -E "Loop|ok|FAIL|failure|Done|error" | uniq
echo "== MEMTEST noidle end rc=$?" > /dev/kmsg; echo done
