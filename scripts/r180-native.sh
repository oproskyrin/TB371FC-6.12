#!/bin/sh
# R180 (on the tablet, test boot): bring up the native display step by step and show a test pattern.
# KDE is stopped first (msm replaces simpledrm). Usage: sh r180-native.sh [seconds]
t=${1:-60}; d=/run/r180; mkdir -p $d
log() { echo "R180: $*"; echo "R180: $*" > /dev/kmsg; }
systemctl stop r149-plasma; sleep 2
for i in $(seq 1 60); do lsmod | grep -q "^clk_rpmh" && break; sleep 1; done
lsmod | grep -q "^clk_rpmh" || { log "clk-rpmh not loaded"; exit 1; }
insmod /run/r180-mod/dispcc-sm8250.ko && log "dispcc loaded"
sleep 1
[ -e /sys/devices/platform/soc@0/ae00000.display-subsystem/driver ] || { printf ae00000.display-subsystem > /sys/bus/platform/drivers/msm-mdss/bind; log "mdss bind rc=$?"; }
sleep 2
for n in ae01000.display-controller ae94000.dsi ae96000.dsi ae94400.phy ae96400.phy; do
  p=$(ls -d /sys/devices/platform/soc@0/ae00000.display-subsystem/$n 2>/dev/null); echo "$n driver=$(basename $(readlink $p/driver 2>/dev/null) 2>/dev/null)"
done
echo N > /sys/module/msm/parameters/fbdev
lsmod | grep -q "^backlight" || insmod /run/r180-mod/backlight.ko
insmod /run/r180-mod/panel-novatek-nt36523.ko keep_splash=${KEEP:-1} && log "panel module loaded keep_splash=${KEEP:-1}"
sleep 5
ls -l /sys/class/drm/ | awk '{print $9}' | tr '\n' ' '; echo
dmesg | grep -i -E "msm|dsi|dpu|panel|nt365" | grep -v "probe of\|initcall\|calling" | tail -15
c=$(modetest -M msm -c 2>/dev/null | awk '/^[0-9]+\t[0-9]+\tconnected/{print $1; exit}')
crtc=$(modetest -M msm -p 2>/dev/null | awk '/^CRTCs:/{f=1;next} f&&/^[0-9]+/{print $1; exit}')
echo "connector=$c crtc=$crtc"; modetest -M msm -c 2>/dev/null | grep -A6 "^$c" | head -8
log "modeset ${t}s begin"
setsid sh -c "sleep $t | timeout $((t+2)) modetest -M msm -s $c@$crtc:2944x1840-120 > $d/modetest.out 2>&1; echo \"R180: modetest rc=\$?\" > /dev/kmsg" >/dev/null 2>&1 &
sleep 10
head -5 $d/modetest.out
echo "smmu faults: $(dmesg | grep -c 'Unhandled context fault')  dsi errors: $(dmesg | grep -c 'dsi_err_worker')"
insmod /run/r180-mod/tb371fc-regdump.ko && dmesg | grep TB371FC_REG | sed 's/^\[[^]]*\] //' > $d/regdump-612.txt; rmmod tb371fc_regdump
wc -l $d/regdump-612.txt
dmesg | grep -v -E "cpufreq|TB371FC_REG|spmi|irq 130|->|IRQ_" | tail -15
