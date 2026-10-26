#!/usr/bin/env bash
set -euo pipefail
project="$(cd "$(dirname "$0")/.." && pwd)"
base=/mnt/d/TB371FC-builds/checkpoints/r129-arch612-headless-20261024
pkg=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r130-usb2-late
(cd "$base"; sha256sum -c SHA256SUMS)
test -s "$pkg/Image"
test -s "$pkg/board.dtb"
test ! -e "$pkg/initramfs.cpio.gz"
stage=$(mktemp -d /root/tb371fc/r130-initramfs.XXXXXX)
printf '%s\n' "$stage" > "$pkg/staging-path.txt"
(cd "$stage"; gzip -dc "$base/initramfs.cpio.gz" | cpio -idmu --quiet)
cp "$stage/bin/boot-arch-development-rootfs" "$stage/bin/boot-arch-r129-base"
cmp "$stage/bin/boot-arch-r129-base" "$project/scripts/r129-overlay-arch-loader.sh"
cp "$project/scripts/r130/boot-wrapper.sh" "$stage/bin/boot-arch-development-rootfs"
cp "$project/scripts/r130/skip-early-usb.sh" "$stage/bin/setup-usb-console"
mkdir "$stage/r130-config" "$stage/r130-modules"
cp "$project/scripts/r130/"* "$stage/r130-config/"
cp "$stage/r129-config/r129-evidence.sh" "$stage/r130-config/r129-evidence-original.sh"
cp "$project/scripts/r130/after-arch.sh" "$stage/r129-config/r129-evidence.sh"
cp "$project/artifacts/tb371fc-development-ssh/id_ed25519.pub" "$stage/r130-config/id_ed25519.pub"
cp "$pkg/dwc3-qcom.ko" "$pkg/phy-qcom-snps-femto-v2.ko" "$stage/r130-modules/"
chmod 0644 "$stage/r130-config/"* "$stage/r130-modules/"*
chmod 0755 "$stage/r130-config/"*.sh "$stage/bin/setup-usb-console" "$stage/bin/boot-arch-development-rootfs" "$stage/bin/boot-arch-r129-base" "$stage/r129-config/r129-evidence.sh"
for file in "$stage/r130-config/"*.sh "$stage/bin/boot-arch-development-rootfs" "$stage/bin/setup-usb-console" "$stage/r129-config/r129-evidence.sh"; do
    sh -n "$file"
done
ssh-keygen -lf "$stage/r130-config/id_ed25519.pub" > "$pkg/authorized-key-fingerprint.txt"
(cd "$stage"; find . -print0 | sort -z | cpio --null -o --format=newc --owner=0:0 --quiet | gzip -9n) > "$pkg/initramfs.cpio.gz"
(cd "$pkg"; sha256sum Image board.dtb initramfs.cpio.gz *.ko System.map .config > SHA256SUMS; tar -czf r130-payload.tar.gz Image board.dtb initramfs.cpio.gz; cat SHA256SUMS)
