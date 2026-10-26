#!/bin/sh
# R146: stages -> step6 (msm fbdev off) -> plain modeset held 60 s.
set -eu
cat /proc/sys/kernel/random/boot_id
st=/run/r134/config/r137-native-stage.sh
for p in rpmh power dispcc icc backlight panel; do
    [ -f /run/r137/$p.ok ] && continue
    sh $st $p > /run/r137/$p.out 2>&1 || { echo "stage $p FAILED"; tail /run/r137/$p.out; exit 1; }
done
echo "stages ok"
echo N > /sys/module/msm/parameters/fbdev
sh /run/r134/config/r139-step.sh 6 | tail -1
sleep 3
echo "R146 host: plain modeset 60s begin" > /dev/kmsg
setsid sh -c 'sleep 60 | timeout 62 modetest -M msm -s 33@89:2944x1840-60 > /run/r146-modetest.out 2>&1; echo "R146 host: modetest rc=$?" > /dev/kmsg' > /dev/null 2>&1 &
sleep 12
head -5 /run/r146-modetest.out
echo "smmu faults: $(dmesg | grep -c 'Unhandled context fault')"
echo "dsi errors: $(dmesg | grep -c 'dsi_err_worker')"
dmesg | grep -v cpufreq | tail -12
