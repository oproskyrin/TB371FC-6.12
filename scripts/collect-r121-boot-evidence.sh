#!/bin/sh
# Read-only evidence collector; redirect stdout on the host to retain the log.
set -u
printf '\n=== kernel and boot ===\n'
uname -a
cat /proc/sys/kernel/random/boot_id /proc/uptime /proc/cmdline
printf '\n=== panic and kexec ===\n'
cat /proc/sys/kernel/panic /sys/kernel/kexec_loaded 2>/dev/null
printf '\n=== storage ===\n'
cat /proc/partitions /proc/mounts
printf '\n=== MMC ===\n'
for f in /sys/kernel/debug/mmc*/ios; do
    [ -r "$f" ] && cat "$f"
done
printf '\n=== deferred probes ===\n'
cat /sys/kernel/debug/devices_deferred 2>/dev/null
printf '\n=== interrupts ===\n'
cat /proc/interrupts
printf '\n=== preserved handoff ===\n'
for f in /var/log/tb371fc-r121/*; do
    [ -f "$f" ] || continue
    printf '\n--- %s ---\n' "$f"
    cat "$f"
done
printf '\n=== kernel messages ===\n'
dmesg
printf '\n=== evidence complete ===\n'
