#!/bin/sh
# R158 test: block every sleep state for this boot (runtime mask, RAM only) and
# report what KDE/PowerDevil would do on idle.
cat /proc/sys/kernel/random/boot_id /proc/uptime
systemctl mask --runtime sleep.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target 2>&1 | tail -2
systemctl is-enabled sleep.target suspend.target
cat /sys/power/state /sys/power/mem_sleep 2>&1
ls /sys/class/power_supply 2>&1
su alarm -c 'kreadconfig6 --file powermanagementprofilesrc --group AC --group SuspendAndShutdown --key AutoSuspendIdleTimeoutSec; kreadconfig6 --file powermanagementprofilesrc --group Battery --group SuspendAndShutdown --key AutoSuspendIdleTimeoutSec' 2>&1
journalctl -b --no-pager | grep -i -E 'suspend|sleep|powerdevil|idle' | tail -8
