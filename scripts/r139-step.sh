#!/bin/sh
set -eu
step=${1:-}
case "$step" in 1|2|3|4|5|6) ;; *) echo 'usage: r139-step.sh 1..6' >&2; exit 2;; esac
test -d /sys/module/r139_panel
test -f /run/r137/backlight.ok
for node in ae94400.phy ae96400.phy; do
    test -L /sys/devices/platform/soc@0/ae00000.display-subsystem/$node/driver
done
panel=
for node in /sys/bus/mipi-dsi/devices/*; do
    if [ "$(tr -d '\000' < "$node/of_node/compatible" 2>/dev/null || true)" = lenovo,tb371fc-tianma-nt36532novatek,nt36523 ]; then
        panel=$(basename "$node")
        break
    fi
done
[ -n "$panel" ]
test ! -L /sys/bus/mipi-dsi/devices/"$panel"/driver
mkdir -p /run/r139
cat /proc/sys/kernel/random/boot_id /proc/uptime > /run/r139/step-$step-before.txt
dmesg > /run/r139/dmesg-before-$step.txt
printf '%s' "$step" > /sys/module/r139_panel/parameters/probe_stage
printf 'R139 host: bind step=%s device=%s\n' "$step" "$panel"
set +e
timeout 30 sh -c 'printf "%s" "$1" > /sys/bus/mipi-dsi/drivers/panel-novatek-nt36523/bind' sh "$panel"
result=$?
set -e
dmesg > /run/r139/dmesg-after-$step.txt
cat /proc/sys/kernel/random/boot_id /proc/uptime > /run/r139/step-$step-after.txt
printf 'R139 host: bind returned rc=%s; stages1..5 intentionally reject probe after checkpoint\n' "$result"
tail -25 /run/r139/dmesg-after-$step.txt
exit 0
