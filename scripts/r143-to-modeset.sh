#!/bin/sh
# R143: stages -> panel step6 with msm fbdev off -> detached modeset with DRM debug.
set -eu
cat /proc/sys/kernel/random/boot_id
st=/run/r134/config/r137-native-stage.sh
for p in rpmh power dispcc icc backlight panel; do
    [ -f /run/r137/$p.ok ] && continue
    sh $st $p > /run/r137/$p.out 2>&1 || { echo "stage $p FAILED"; tail /run/r137/$p.out; exit 1; }
    echo "stage $p ok"
done
echo N > /sys/module/msm/parameters/fbdev
sh /run/r134/config/r139-step.sh 6 | tail -2
sleep 3
modetest -M msm -c | grep -E "^[0-9]+\s" | head -3
echo 0x16 > /sys/module/drm/parameters/debug
echo 40 > /proc/sys/kernel/printk_delay
echo "R143 host: modeset 33@89 2944x1840-60 begin" > /dev/kmsg
setsid sh -c 'timeout 40 modetest -M msm -s 33@89:2944x1840-60 < /dev/null > /run/r141-modetest.out 2>&1; echo "R143 host: modetest rc=$?" > /dev/kmsg; echo 0 > /sys/module/drm/parameters/debug' > /dev/null 2>&1 &
echo started
