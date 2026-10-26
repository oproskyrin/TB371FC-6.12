#!/bin/sh
# R164 checks after boot: cpufreq-hw, thermal zones/temps, audio, Wi-Fi, apps layer.
uname -r; cat /proc/uptime; date
findmnt -n -o OPTIONS / | tr ',' '\n' | grep lowerdir
for p in /sys/devices/system/cpu/cpufreq/policy*; do echo "$(basename $p) drv=$(cat $p/scaling_driver) gov=$(cat $p/scaling_governor) cur=$(cat $p/scaling_cur_freq) min=$(cat $p/cpuinfo_min_freq) max=$(cat $p/cpuinfo_max_freq)"; done 2>&1
n=0; for z in /sys/class/thermal/thermal_zone*; do n=$((n+1)); done; echo "thermal zones: $n"
for z in /sys/class/thermal/thermal_zone*; do echo "$(cat $z/type)=$(cat $z/temp 2>/dev/null)"; done 2>/dev/null | head -40 | tr '\n' ' '; echo
ls /sys/class/thermal | grep -c cooling_device
grep -E "done|no card|rescan|started|no wlp" /run/r163-audio.log /run/r163-wifi.log 2>/dev/null
ip -br addr show wlp1s0 2>&1; cat /proc/asound/cards | head -1
dmesg | grep -i -E "cpufreq|tsens|thermal" | grep -v -E "initcall|calling|returned 517" | tail -8 | cut -c1-160
