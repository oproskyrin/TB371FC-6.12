#!/usr/bin/env bash
set -euo pipefail
base=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r125-no-gpio75-hog/board.dtb
pkg=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r127-reserve-all-gpios
node=/soc/pinctrl@f100000
printf '%s  %s\n' 95c53bfe82d42c11110b2eb970167962a9ee0583e688071c594e1fa198719afe "$base" | sha256sum -c -
test "$(fdtget -t i "$base" "$node" gpio-reserved-ranges)" = '40 4'
test ! -e "$pkg"
mkdir "$pkg"
cp "$base" "$pkg/board.dtb"
# R118 SM8250 driver exposes ngpios=181. Avoid all get_direction MMIO reads.
fdtput -t i "$pkg/board.dtb" "$node" gpio-reserved-ranges 0 181
test "$(fdtget -t i "$pkg/board.dtb" "$node" gpio-reserved-ranges)" = '0 181'
dtc -q -I dtb -O dts "$base" > "$pkg/baseline.dts"
dtc -q -I dtb -O dts "$pkg/board.dtb" > "$pkg/candidate.dts"
diff -u "$pkg/baseline.dts" "$pkg/candidate.dts" > "$pkg/dtb.diff" || test "$?" = 1
cp "$pkg/board.dtb" "$pkg/roundtrip.dtb"
fdtput -t i "$pkg/roundtrip.dtb" "$node" gpio-reserved-ranges 40 4
dtc -q -I dtb -O dts "$pkg/roundtrip.dtb" > "$pkg/roundtrip.dts"
cmp "$pkg/baseline.dts" "$pkg/roundtrip.dts"
(cd "$pkg"; sha256sum board.dtb > SHA256SUMS; cat SHA256SUMS; cat dtb.diff)
