#!/bin/sh
set -eu
base=/run/r183-baseline
test ! -e "$base"
mkdir "$base"
uname -a > "$base/identity.txt"
cat /proc/sys/kernel/random/boot_id /proc/cmdline >> "$base/identity.txt"
cat /sys/firmware/fdt > "$base/live.dtb"
systemctl cat r149-plasma.service > "$base/plasma-service.txt"
cp -a /etc/systemd/system/r149-plasma.service "$base/"
for f in /home/alarm/.config/kwinrc /home/alarm/.config/kwinoutputconfig.json; do
    [ ! -f "$f" ] || cp -a "$f" "$base/"
done
pacman -Q > "$base/packages.txt"
findmnt > "$base/mounts.txt"
dmesg > "$base/dmesg.txt"
tar -czf /run/r183-baseline.tar.gz -C /run r183-baseline
sha256sum /run/r183-baseline.tar.gz
