#!/bin/sh
# R164 diagnostic: 8-core load for up to 120 s with temperature log every 5 s; the load is
# stopped at once if any thermal zone exceeds 90 C.
pids=""; for i in 1 2 3 4 5 6 7 8; do (while :; do :; done) & pids="$pids $!"; done
max() { m=0; for z in /sys/class/thermal/thermal_zone*/temp; do t=$(cat $z 2>/dev/null || echo 0); [ "$t" -gt "$m" ] && m=$t; done; echo $m; }
for s in $(seq 0 5 120); do
  m=$(max); echo "t=${s}s max=$((m/1000))C cpu4=$(cat /sys/class/thermal/thermal_zone2/temp) $(cat /sys/class/thermal/thermal_zone*/type | head -0)"
  [ "$m" -gt 90000 ] && { echo "LIMIT 90C reached, stopping load"; break; }
  sleep 5
done
kill $pids 2>/dev/null; sleep 10; echo "after 10 s idle: max=$(( $(max)/1000 ))C"
