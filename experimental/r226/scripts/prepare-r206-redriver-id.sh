#!/bin/bash
# Isolate stock retimer identification from USB3: R201 USB2 + SE9 only.
set -euo pipefail
base=/mnt/d/TB371FC-builds/r201-display
dest=/mnt/d/TB371FC-builds/r206-redriver-id
mkdir -p "$dest"
test "$(sha256sum "$base/board.dtb" | cut -d' ' -f1)" = 04a223660b5c281c181d2180329db0ba62654ed6441d121ded8a7d38b1106a8a
cp "$base/Image" "$base/board.dtb" "$base/initramfs.cpio.gz" "$dest/"
d=$dest/board.dtb
test "$(fdtget -t i "$d" /soc@0/pinctrl@f100000 gpio-reserved-ranges)" = '0 12 14 2 22 10 33 3 38 2 46 10 57 3 62 6 70 5 76 3 83 25 109 1 111 3 121 17 142 39'
fdtput -t i "$d" /soc@0/pinctrl@f100000 gpio-reserved-ranges 0 12 14 2 22 10 33 3 38 2 46 10 57 3 62 6 70 5 76 3 83 25 109 1 111 3 121 4 127 11 142 39
fdtput -t s "$d" /soc@0/geniqup@ac0000/i2c@a84000 status okay
fdtput -t i "$d" /soc@0/geniqup@ac0000/i2c@a84000 clock-frequency 100000
fdtput -t s "$d" /chosen tb371fc,experiment r206-redriver-readonly
cd "$dest"
sha256sum Image board.dtb initramfs.cpio.gz > SHA256SUMS
cat SHA256SUMS
tar -czf r206-probe-payload.tar.gz Image board.dtb initramfs.cpio.gz SHA256SUMS
