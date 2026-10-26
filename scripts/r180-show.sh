#!/bin/sh
# R180: show the modetest pattern in a given mode for N seconds (default 2944x1840-120, 900 s).
mode=${1:-2944x1840-120}; t=${2:-900}
for p in $(pgrep -x modetest); do kill $p; done; sleep 2
setsid sh -c "sleep $t | timeout $((t+2)) modetest -M msm -s 33@89:$mode > /run/r180/modetest.out 2>&1" >/dev/null 2>&1 &
sleep 8; head -3 /run/r180/modetest.out
insmod /run/r180-mod/tb371fc-regdump.ko; dmesg | grep -E "TB371FC_REG (0ae94020|0ae96020|0ae81000)" | tail -3; rmmod tb371fc_regdump
echo "smmu: $(dmesg | grep -c 'Unhandled context fault') dsi_err: $(dmesg | grep -c dsi_err_worker)"
