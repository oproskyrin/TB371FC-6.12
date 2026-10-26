#!/usr/bin/env bash
set -euo pipefail
project="$(cd "$(dirname "$0")/.." && pwd)"
base=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r127-reserve-all-gpios/board.dtb
inner=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r118-pinctrl/initramfs.cpio.gz
pkg=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r128-gpio75-readonly
printf '%s  %s\n' eb2a21d965b18fa17f8244df249c1e9ebe0829fffd71c445317922e169ef33fc "$base" | sha256sum -c -
printf '%s  %s\n' 9315af03cb90f8014c881a63c26db214bf0a28a8acb7203d37d3f488098ebfc0 "$inner" | sha256sum -c -
test ! -e "$pkg"
mkdir "$pkg"
cp "$base" "$pkg/board.dtb"
node=/soc/pinctrl@f100000
fdtput -t i "$pkg/board.dtb" "$node" gpio-reserved-ranges 0 75 76 105
fdtput -d "$pkg/board.dtb" "$node/sd-redriver-hog" status
dtc -q -I dtb -O dts "$base" > "$pkg/baseline.dts"
dtc -q -I dtb -O dts "$pkg/board.dtb" > "$pkg/candidate.dts"
diff -u "$pkg/baseline.dts" "$pkg/candidate.dts" > "$pkg/dtb.diff" || test "$?" = 1
cp "$pkg/board.dtb" "$pkg/roundtrip.dtb"
fdtput -t i "$pkg/roundtrip.dtb" "$node" gpio-reserved-ranges 0 181
fdtput -t s "$pkg/roundtrip.dtb" "$node/sd-redriver-hog" status disabled
dtc -q -I dtb -O dts "$pkg/roundtrip.dtb" > "$pkg/roundtrip.dts"
cmp "$pkg/baseline.dts" "$pkg/roundtrip.dts"
stage=$(mktemp -d /root/tb371fc/r128-initramfs.XXXXXX)
printf '%s\n' "$stage" > "$pkg/staging-path.txt"
(cd "$stage"; gzip -dc "$inner" | cpio -idmu --quiet)
cp "$project/scripts/r128-readonly-sd-probe.sh" "$stage/bin/boot-arch-development-rootfs"
chmod 0755 "$stage/bin/boot-arch-development-rootfs"
sh -n "$stage/bin/boot-arch-development-rootfs"
(cd "$stage"; find . -print0 | sort -z | cpio --null -o --format=newc --owner=0:0 --quiet | gzip -9n) > "$pkg/initramfs.cpio.gz"
(cd "$pkg"; sha256sum board.dtb initramfs.cpio.gz > SHA256SUMS; tar -czf r128-payload.tar.gz board.dtb initramfs.cpio.gz; cat SHA256SUMS; cat dtb.diff)
