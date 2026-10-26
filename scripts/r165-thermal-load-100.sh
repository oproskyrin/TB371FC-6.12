#!/bin/sh
# R165 diagnostic: 8-core load for up to 180 s with temperature log every 5 s; the load is
# stopped at once if any thermal zone exceeds 100 C.
pids=""; for i in 1 2 3 4 5 6 7 8; do (while :; do :; done) & pids="$pids $!"; done
max() { m=0; for z in /sys/class/thermal/thermal_zone*/temp; do t=$(cat $z 2>/dev/null || echo 0); [ "$t" -gt "$m" ] && m=$t; done; echo $m; }
for s in $(seq 0 10 150); do
  m=$(max); echo "t=${s}s max=$((m/1000))C f0=$(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_cur_freq) f4=$(cat /sys/devices/system/cpu/cpufreq/policy4/scaling_cur_freq) f7=$(cat /sys/devices/system/cpu/cpufreq/policy7/scaling_cur_freq)"
  [ "$m" -gt 100000 ] && { echo "LIMIT 100C reached, stopping load"; break; }
  sleep 5
done
kill $pids 2>/dev/null; sleep 10; echo "after 10 s idle: max=$(( $(max)/1000 ))C"
