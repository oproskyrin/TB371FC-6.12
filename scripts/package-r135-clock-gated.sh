#!/usr/bin/env bash
set -euo pipefail
project="$(cd "$(dirname "$0")/.." && pwd)"
base=/mnt/d/TB371FC-builds/linux-6.12-r134-panel
module=/mnt/d/TB371FC-builds/r135-rpmh-clock
pkg=/mnt/d/TB371FC-builds/r135-clock-gated
test ! -e "$pkg"
mkdir "$pkg"
(cd "$base"; sha256sum -c SHA256SUMS)
(cd "$module"; sha256sum -c SHA256SUMS)
stage=$(mktemp -d /root/tb371fc/r135-initramfs.XXXXXX)
printf '%s\n' "$stage" > "$pkg/staging-path.txt"
(cd "$stage"; gzip -dc "$base/initramfs.cpio.gz" | cpio -idmu --quiet)
cp "$base/Image" "$base/board.dtb" "$pkg/"
cp "$module/clk-rpmh.ko" "$stage/r134-modules/"
cp "$project/scripts/r135-display-stage.sh" "$stage/r134-config/"
cp "$project/scripts/r135-clock-only.sh" "$stage/r134-config/late-display-deps.sh"
chmod 0755 "$stage/r134-config/"*.sh
cmp "$stage/bin/boot-arch-r129-base" "$project/scripts/r129-overlay-arch-loader.sh"
test ! -e "$stage/r130-config/id_ed25519"
cmp "$stage/r130-config/id_ed25519.pub" "$project/artifacts/tb371fc-development-ssh/id_ed25519.pub"
for file in "$stage/r134-config/"*.sh; do sh -n "$file"; done
test "$(fdtget -t i "$pkg/board.dtb" /soc/pinctrl@f100000 gpio-reserved-ranges)" = '0 75 76 105'
for node in dsi@ae94000 dsi@ae96000; do
    test "$(fdtget -t s "$pkg/board.dtb" /soc/display-subsystem@ae00000/$node status)" = disabled
done
for file in "$stage/r134-modules/"*.ko; do
    modinfo -F vermagic "$file" | grep -q '^6.12.30-tb371fc-r134-panel+ '
done
test "$(find "$stage/r134-modules" -name '*.ko' | wc -l)" -eq 10
(cd "$stage"; find . -print0 | sort -z | cpio --null -o --format=newc --owner=0:0 --quiet | gzip -9n) > "$pkg/initramfs.cpio.gz"
(cd "$pkg"; sha256sum Image board.dtb initramfs.cpio.gz > SHA256SUMS; tar -czf r135-clock-gated-payload.tar.gz Image board.dtb initramfs.cpio.gz; cat SHA256SUMS)
