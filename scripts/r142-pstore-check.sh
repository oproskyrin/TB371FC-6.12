#!/bin/sh
cat /proc/sys/kernel/random/boot_id /proc/uptime
dmesg | grep -i -E "ramoops|pstore|persistent_ram" | head
grep pstore /proc/mounts || mount -t pstore pstore /sys/fs/pstore
ls -la /sys/fs/pstore
for f in /sys/fs/pstore/*; do [ -f "$f" ] && { echo "=== $f"; tail -c 6000 "$f"; }; done
