#!/usr/bin/env bash
set -euo pipefail
base=/mnt/d/TB371FC-builds/checkpoints/r130-arch612-usb-ssh-20261024
pkg=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r131-rpmh-domain
if [ "${1:-}" != --finish ]; then
test ! -e "$pkg"
mkdir "$pkg"
printf '%s  %s\n' c502aa0a1b157c7a35ed2506c68555fa5ef5c42991fbc446e8f7560b701cc390 "$base/board.dtb" | sha256sum -c -
printf '%s  %s\n' 03b2f15272040962984d70f77356b9686429f0b7024d85ed8fa4150b6129ec61 "$base/Image" | sha256sum -c -
printf '%s  %s\n' cb68f76732b8c21c6ca8dfec7ca886c006082210fde78ede4da552d2fbcbaa70 "$base/initramfs.cpio.gz" | sha256sum -c -
cp "$base/Image" "$base/initramfs.cpio.gz" "$base/board.dtb" "$pkg/"
test "$(fdtget -t x "$pkg/board.dtb" /soc/rsc@18200000 power-domains)" = 24
fdtput -d "$pkg/board.dtb" /soc/rsc@18200000 power-domains
fi
dtc -q -s -I dtb -O dts "$base/board.dtb" > "$pkg/base-r130.dts"
dtc -q -s -I dtb -O dts "$pkg/board.dtb" > "$pkg/candidate.dts"
diff -u "$pkg/base-r130.dts" "$pkg/candidate.dts" > "$pkg/dtb.diff" || test "$?" = 1
# Roundtrip restoration proves that no other DT property changed.
cp "$pkg/board.dtb" "$pkg/roundtrip.dtb"
fdtput -t x "$pkg/roundtrip.dtb" /soc/rsc@18200000 power-domains 24
dtc -q -s -I dtb -O dts "$pkg/roundtrip.dtb" > "$pkg/roundtrip.dts"
cmp "$pkg/base-r130.dts" "$pkg/roundtrip.dts"
cmp "$pkg/Image" "$base/Image"
cmp "$pkg/initramfs.cpio.gz" "$base/initramfs.cpio.gz"
(cd "$pkg"; sha256sum Image board.dtb initramfs.cpio.gz > SHA256SUMS; tar -czf r131-payload.tar.gz Image board.dtb initramfs.cpio.gz; cat SHA256SUMS; cat dtb.diff)
