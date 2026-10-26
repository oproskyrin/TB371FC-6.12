#!/bin/sh
# Plain modeset (no DRM debug, no printk delay), held for 60 s for a visual check.
echo 0 > /sys/module/drm/parameters/debug
echo 0 > /proc/sys/kernel/printk_delay
echo "R143 host: plain modeset 60s begin" > /dev/kmsg
setsid sh -c 'sleep 60 | timeout 62 modetest -M msm -s 33@89:2944x1840-60 > /run/r143-modetest2.out 2>&1; echo "R143 host: plain modetest rc=$?" > /dev/kmsg' > /dev/null 2>&1 &
sleep 15
cat /run/r143-modetest2.out | head -5
dmesg | grep -c "Unhandled context fault"
dmesg | tail -5
