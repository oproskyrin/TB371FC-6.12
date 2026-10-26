#!/bin/sh
# Read-only R140 evidence collection (runs on the tablet over native SSH).
echo "== identity"; uname -r; cat /proc/sys/kernel/random/boot_id /proc/uptime
echo "== live DT framebuffer props"
fb=/proc/device-tree/chosen/framebuffer@9c000000
ls $fb; od -An -tx4 --endian=big $fb/power-domains; od -An -tx4 --endian=big $fb/required-opps
echo "== rsc power-domains (must be absent)"; ls /proc/device-tree/soc/rsc@18200000/power-domains 2>&1
echo "== genpd summary"; cat /sys/kernel/debug/pm_genpd/pm_genpd_summary 2>/dev/null | grep -E -A3 "^(mmcx|mx|cx) "
echo "== mmcx perf state"; cat /sys/kernel/debug/pm_genpd/mmcx/perf_state 2>/dev/null; cat /sys/kernel/debug/pm_genpd/mmcx/current_state 2>/dev/null; cat /sys/kernel/debug/pm_genpd/mmcx/devices 2>/dev/null
echo "== drm"; ls -l /sys/class/drm/; readlink -f /sys/class/drm/card0/device
echo "== rpmhpd state_synced"; for f in /sys/bus/platform/devices/*rsc*/*power-controller*/state_synced /sys/bus/platform/devices/18200000.rsc:power-controller/state_synced; do [ -e "$f" ] && echo "$f=$(cat $f)"; done
echo "== dmesg simple/genpd/rpmh/mdss"; dmesg | grep -i -E "simpledrm|simple-framebuffer|9c000000|rpmh|genpd|mdss|framebuffer|fbcon|Console" | head -40
echo "== failed"; systemctl --failed --no-pager
echo "== vt"; cat /sys/class/tty/tty0/active; cat /sys/class/graphics/fbcon/cursor_blink 2>/dev/null
