#!/bin/sh
# R141b: pre-stages + panel module stage0, then disable msm fbdev before step 6.
set -eu
cat /proc/sys/kernel/random/boot_id
st=/run/r134/config/r137-native-stage.sh
for p in rpmh power dispcc icc backlight panel; do
    [ -f /run/r137/$p.ok ] && continue
    sh $st $p > /run/r137/$p.out 2>&1 || { echo "stage $p FAILED"; tail /run/r137/$p.out; exit 1; }
    echo "stage $p ok"
done
cat /sys/module/r139_panel/parameters/probe_stage
echo N > /sys/module/msm/parameters/fbdev
echo "msm.fbdev=$(cat /sys/module/msm/parameters/fbdev)"
command -v modetest kmscube drm_info 2>/dev/null || echo "no modetest/kmscube/drm_info"
pacman -Qq 2>/dev/null | grep -E "^libdrm|^drm_info|^kmscube|^mesa" || true
