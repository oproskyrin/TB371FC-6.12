#!/bin/sh
ls -l /sys/class/drm
modetest -M msm -c 2>&1 | head -40
modetest -M msm -e 2>&1 | head -20
modetest -M msm -p 2>&1 | grep -E "^CRTCs|^[0-9]+\s" | head -20
ls /sys/kernel/debug/dri/
cat /sys/kernel/debug/dri/1/state 2>/dev/null | head -40
