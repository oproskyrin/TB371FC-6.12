#!/bin/sh
# R141: run native display pre-stages up to backlight. Stops on first failure.
set -eu
st=/run/r134/config/r137-native-stage.sh
echo "gpu status: $(tr -d '\000' < /proc/device-tree/soc@0/gpu@3d00000/status)"
echo "gmu status: $(tr -d '\000' < /proc/device-tree/soc@0/gmu@3d6a000/status)"
ls /run/r137/ 2>/dev/null | grep '\.ok$' || true
for p in rpmh power dispcc icc backlight; do
    if [ -f /run/r137/$p.ok ]; then echo "== $p already ok"; continue; fi
    echo "== stage $p"
    sh $st $p
    echo "mmcx=$(cat /sys/kernel/debug/pm_genpd/mmcx/perf_state)"
done
echo "== drivers"
for n in ae00000.display-subsystem ae01000.display-controller ae94000.dsi ae96000.dsi ae94400.phy ae96400.phy; do
    p=$(find /sys/devices/platform/soc@0 -maxdepth 2 -name "$n" | head -1)
    echo "$n -> $(readlink "$p/driver" 2>/dev/null | xargs -r basename)"
done
cat /sys/kernel/debug/pm_genpd/pm_genpd_summary | grep -A6 "^mmcx "
ls /sys/class/backlight; cat /sys/class/backlight/*/brightness
lsmod | head -20
dmesg | tail -25
