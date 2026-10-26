#!/bin/sh
# R166: start CPU/GPU throttling earlier (passive trips 75 C instead of 85/90 C) so the tablet
# stays cool; critical trips are left unchanged. Prints what was changed.
set -u
n=0
for z in /sys/class/thermal/thermal_zone*; do
	t=$(cat $z/type)
	case $t in cpu*|gpu*) ;; *) continue;; esac
	for tt in $z/trip_point_*_type; do
		[ "$(cat $tt)" = passive ] || continue
		p=${tt%_type}_temp
		[ "$(cat $p)" -gt 75000 ] && { echo 75000 > $p && n=$((n+1)); }
	done
done
echo "R166 thermal: $n passive trips set to 75 C"
