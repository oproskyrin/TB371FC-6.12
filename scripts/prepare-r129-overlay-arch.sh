#!/usr/bin/env bash
set -euo pipefail
project="$(cd "$(dirname "$0")/.." && pwd)"
base=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r128-gpio75-readonly
pkg=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r129-overlay-arch
(cd "$base"; sha256sum -c SHA256SUMS)
if [ "${1:-}" = --repack ]; then
    stage=$(cat "$pkg/staging-path.txt")
    case "$stage" in /root/tb371fc/r129-initramfs.*) ;; *) exit 1;; esac
    test -f "$stage/init"
else
    test ! -e "$pkg"
    mkdir "$pkg"
    cp "$base/board.dtb" "$pkg/board.dtb"
    stage=$(mktemp -d /root/tb371fc/r129-initramfs.XXXXXX)
    printf '%s\n' "$stage" > "$pkg/staging-path.txt"
    (cd "$stage"; gzip -dc "$base/initramfs.cpio.gz" | cpio -idmu --quiet)
fi
cp "$project/scripts/r129-overlay-arch-loader.sh" "$stage/bin/boot-arch-development-rootfs"
mkdir -p "$stage/r129-config"
cp "$project/scripts/r129/"* "$stage/r129-config/"
chmod 0644 "$stage/r129-config/"*
chmod 0755 "$stage/bin/boot-arch-development-rootfs" "$stage/r129-config/r129-evidence.sh"
sh -n "$stage/bin/boot-arch-development-rootfs"
sh -n "$stage/r129-config/r129-evidence.sh"
(cd "$stage"; find . -print0 | sort -z | cpio --null -o --format=newc --owner=0:0 --quiet | gzip -9n) > "$pkg/initramfs.cpio.gz"
(cd "$pkg"; sha256sum board.dtb initramfs.cpio.gz > SHA256SUMS; tar -czf r129-payload.tar.gz board.dtb initramfs.cpio.gz; cat SHA256SUMS)
