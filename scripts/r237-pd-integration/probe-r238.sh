#!/bin/sh
# Manual SSH-only PD test; NEVER auto-run on boot. Temporary reboot fallback.
set -eu
grep -qw tb371fc.r238 /proc/cmdline
grep -qw systemd.mask=r231-charge-keepalive.service /proc/cmdline
test ! -d /sys/module/r231_charge_keepalive
test ! -d /sys/module/r233_pmic_tcpm
test -n "${SSH_CONNECTION:-}"
server=$(printf '%s\n' "$SSH_CONNECTION" | awk '{print $3}')
ip -4 -o addr show dev wlp1s0 | grep -Fq " $server/"
# 20% was the recommended pre-boot reserve; allow boot consumption down to15%.
test "$(cat /sys/class/power_supply/mm8013/capacity)" -ge 15
test "$(cat /sys/class/power_supply/mm8013/voltage_now)" -ge 3600000
test "$(cat /sys/class/power_supply/mm8013/temp)" -ge 50
test "$(cat /sys/class/power_supply/mm8013/temp)" -le 400
test "$(cat /sys/class/power_supply/mm8013/health)" = Good
test "$(sha256sum /run/r226/r203-usb-regulators.ko | cut -d ' ' -f1)" = 11086624b59050cc14c325dfb53c48fcdf135179b1f58ffc4e254810ff1bc942
cd /run/r238
sha256sum -c SHA256SUMS
# Exact unchanged fallback remains installed. Reboot is not an electrical reset
# guarantee: input may remain conservatively limited after a failed probe.
systemd-run --unit=r238-rescue --on-active=180s /usr/bin/systemctl --no-block reboot
insmod ./tcpm.ko
insmod ./r233_pmic_tcpm.ko
source=/sys/class/power_supply/tcpm-source-psy-c440000.spmi:pmic@2:typec@1500
# Don't guess kernel device naming: find the unique TCPM source by class path.
n=0
while [ "$n" -lt 50 ]; do
    for s in /sys/class/power_supply/tcpm-source-psy-*; do
        [ -e "$s/online" ] || continue
        source=$s
    done
    if [ -e "$source/online" ] && [ "$(cat "$source/online")" = 1 ] &&
       [ "$(cat "$source/voltage_now")" = 5000000 ]; then
        break
    fi
    n=$((n+1)); sleep 1
done
test "$n" -lt 50
insmod ./r235-watchdog-only.ko
sleep 6
test "$(cat /sys/module/r235_watchdog_only/parameters/fault)" = 0
test "$(cat /sys/module/r235_watchdog_only/parameters/pets)" -gt 0
echo 'R238 PD/watchdog candidate running; FALLBACK TIMER STILL ARMED'
cat "$source/online" "$source/voltage_now" "$source/current_max"
cat /sys/class/power_supply/mm8013/status /sys/class/power_supply/mm8013/current_now
# Operator must not disable fallback until logs and sustained charge are checked.
