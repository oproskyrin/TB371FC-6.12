#!/usr/bin/env bash
set -euo pipefail
project="$(cd "$(dirname "$0")/.." && pwd)"
base=/mnt/d/TB371FC-builds/checkpoints/r131-arch612-rpmh-usb-20261024
pkg=/mnt/d/TB371FC-builds/linux-6.12-r134-panel
test -s "$pkg/Image"
test ! -e "$pkg/initramfs.cpio.gz"
(cd "$pkg"; sha256sum -c SHA256SUMS)
printf '%s  %s\n' 7c11303edcd7a0b8b21389a5065f8048f36d81cefe358a6f5f9297edc76a9aab "$base/board.dtb" | sha256sum -c -
printf '%s  %s\n' cb68f76732b8c21c6ca8dfec7ca886c006082210fde78ede4da552d2fbcbaa70 "$base/initramfs.cpio.gz" | sha256sum -c -
cp "$base/board.dtb" "$pkg/"
stage=$(mktemp -d /root/tb371fc/r134-initramfs.XXXXXX)
printf '%s\n' "$stage" > "$pkg/staging-path.txt"
(cd "$stage"; gzip -dc "$base/initramfs.cpio.gz" | cpio -idmu --quiet)
cmp "$stage/bin/boot-arch-r129-base" "$project/scripts/r129-overlay-arch-loader.sh"
cp "$stage/bin/boot-arch-development-rootfs" "$stage/bin/boot-arch-r130-wrapper"
cp "$project/scripts/r134/boot-wrapper.sh" "$stage/bin/boot-arch-development-rootfs"
mkdir "$stage/r134-config" "$stage/r134-modules"
cp "$project/scripts/r134/"* "$stage/r134-config/"
cp "$stage/r129-config/r129-evidence.sh" "$stage/r134-config/r130-after-arch.sh"
cp "$project/scripts/r134/after-arch.sh" "$stage/r129-config/r129-evidence.sh"
cp "$pkg/modules/"*.ko "$stage/r134-modules/"
cp "$pkg/modules/dwc3-qcom.ko" "$pkg/modules/phy-qcom-snps-femto-v2.ko" "$stage/r130-modules/"
chmod 0644 "$stage/r134-config/"* "$stage/r134-modules/"* "$stage/r130-modules/"*
chmod 0755 "$stage/r134-config/"*.sh "$stage/bin/boot-arch-development-rootfs" "$stage/bin/boot-arch-r130-wrapper" "$stage/r129-config/r129-evidence.sh"
test ! -e "$stage/r130-config/id_ed25519"
cmp "$stage/r130-config/id_ed25519.pub" "$project/artifacts/tb371fc-development-ssh/id_ed25519.pub"
for file in "$stage/r134-config/"*.sh "$stage/bin/boot-arch-development-rootfs"; do sh -n "$file"; done
test "$(fdtget -t i "$pkg/board.dtb" /soc/pinctrl@f100000 gpio-reserved-ranges)" = '0 75 76 105'
for node in dsi@ae94000 dsi@ae96000; do
    test "$(fdtget -t s "$pkg/board.dtb" /soc/display-subsystem@ae00000/$node status)" = disabled
done
(cd "$stage"; find . -print0 | sort -z | cpio --null -o --format=newc --owner=0:0 --quiet | gzip -9n) > "$pkg/initramfs.cpio.gz"
(cd "$pkg"; sha256sum Image board.dtb initramfs.cpio.gz modules/*.ko .config System.map > SHA256SUMS; tar -czf r134-control-payload.tar.gz Image board.dtb initramfs.cpio.gz; cat SHA256SUMS)
