#!/usr/bin/env bash
# R158 payload: R157 (R140 Image + R153 DTB + R149b initramfs) + sleep states masked at boot.
set -euo pipefail
project="$(cd "$(dirname "$0")/.." && pwd)"
b=/mnt/d/TB371FC-builds/r157-stable
pkg=/mnt/d/TB371FC-builds/r158-nosleep
test ! -e "$pkg"
(cd "$b"; grep -E " (Image|board.dtb|initramfs.cpio.gz)$" SHA256SUMS | sha256sum -c -)
mkdir -p "$pkg"; cp "$b/Image" "$b/board.dtb" "$pkg/"
stage=$(mktemp -d /root/tb371fc/r158-initramfs.XXXXXX); echo "$stage" > "$pkg/staging-path.txt"
(cd "$stage"; gzip -dc "$b/initramfs.cpio.gz" | cpio -idmu --quiet)
ev="$stage/r129-config/r129-evidence.sh"
tail -1 "$ev" | grep -q '^/run/r130/busybox sh /run/r130/config/r149-install.sh$'
cp "$project/scripts/r158-config/r158-install.sh" "$stage/r130-config/"
sed -i 's/\r$//' "$stage/r130-config/r158-install.sh"; sh -n "$stage/r130-config/r158-install.sh"
# mask sleep first, before KDE can idle-suspend
sed -i 's#^/run/r130/busybox sh /run/r130/config/r149-install.sh$#/run/r130/busybox sh /run/r130/config/r158-install.sh\n/run/r130/busybox sh /run/r130/config/r149-install.sh#' "$ev"
sh -n "$ev"; tail -3 "$ev"
(cd "$stage"; find . -print0 | sort -z | cpio --null -o --format=newc --owner=0:0 --quiet | gzip -9n) > "$pkg/initramfs.cpio.gz"
cd "$pkg"; sha256sum Image board.dtb initramfs.cpio.gz > SHA256SUMS
tar -czf r158-payload.tar.gz Image board.dtb initramfs.cpio.gz; sha256sum r158-payload.tar.gz >> SHA256SUMS; cat SHA256SUMS
