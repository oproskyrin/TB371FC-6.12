#!/bin/sh
# Controlled first modeset on native msm with DRM debug; runs detached.
mkdir -p /run/r141
dmesg > /run/r141/dmesg-before-modeset.txt
echo 0x16 > /sys/module/drm/parameters/debug
echo "R141b host: modeset 33@89 2944x1840-60 begin" > /dev/kmsg
setsid sh -c 'timeout 25 modetest -M msm -s 33@89:2944x1840-60 < /dev/null > /run/r141/modetest.out 2>&1; echo "R141b host: modetest rc=$?" > /dev/kmsg; echo 0 > /sys/module/drm/parameters/debug' > /dev/null 2>&1 &
echo started
