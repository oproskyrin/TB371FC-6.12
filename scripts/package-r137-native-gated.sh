#!/usr/bin/env bash
set -euo pipefail
project="$(cd "$(dirname "$0")/.." && pwd)"
pkg=/mnt/d/TB371FC-builds/r137-native-prereqs
base=/mnt/d/TB371FC-builds/r135-clock-gated
if [ -e "$pkg/initramfs.cpio.gz" ]; then
    test "${1:-}" = --repack
    cp -n "$pkg/initramfs.cpio.gz" "$pkg/initramfs.before-banner.cpio.gz"
fi
(cd "$pkg"; sha256sum -c SHA256SUMS)
(cd "$base"; sha256sum -c SHA256SUMS)
stage=$(mktemp -d /root/tb371fc/r137-initramfs.XXXXXX)
printf '%s\n' "$stage" > "$pkg/staging-path.txt"
(cd "$stage"; gzip -dc "$base/initramfs.cpio.gz" | cpio -idmu --quiet)
cp "$pkg/modules/"*.ko "$stage/r134-modules/"
cp "$pkg/modules/dwc3-qcom.ko" "$pkg/modules/phy-qcom-snps-femto-v2.ko" "$stage/r130-modules/"
cp "$project/scripts/r137-native-stage.sh" "$stage/r134-config/"
cp "$project/scripts/r137-clock-only.sh" "$stage/r134-config/late-display-deps.sh"
cp "$project/scripts/r137-boot-wrapper.sh" "$stage/bin/boot-arch-development-rootfs"
chmod 0755 "$stage/bin/boot-arch-development-rootfs"
(cd "$pkg/modules"; sha256sum *.ko) > "$stage/r134-config/r137-modules.sha256"
chmod 0755 "$stage/r134-config/"*.sh
cmp "$stage/bin/boot-arch-r129-base" "$project/scripts/r129-overlay-arch-loader.sh"
test ! -e "$stage/r130-config/id_ed25519"
cmp "$stage/r130-config/id_ed25519.pub" "$project/artifacts/tb371fc-development-ssh/id_ed25519.pub"
for file in "$stage/r134-config/"*.sh; do sh -n "$file"; done
cp "$pkg/native-gated.dtb" "$pkg/board.dtb"
(cd "$stage"; find . -print0 | sort -z | cpio --null -o --format=newc --owner=0:0 --quiet | gzip -9n) > "$pkg/initramfs.cpio.gz"
(cd "$pkg"; sha256sum Image board.dtb initramfs.cpio.gz modules/*.ko .config System.map > SHA256SUMS; tar -czf r137-native-gated-payload.tar.gz Image board.dtb initramfs.cpio.gz; cat SHA256SUMS)
