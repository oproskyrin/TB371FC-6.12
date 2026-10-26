#!/usr/bin/env bash
# R154 test payload: R140 Image + R154 DTB (SD non-removable) + R152 initramfs.
set -euo pipefail
pkg=/mnt/d/TB371FC-builds/r154-persist
b=/mnt/d/TB371FC-builds/r152-wifi-autostart
(cd "$b"; grep -E " (Image|initramfs.cpio.gz)$" SHA256SUMS | sha256sum -c -)
test "$(sha256sum "$pkg/board.dtb" | cut -d' ' -f1)" = d0e835b52ba54990dc7653e9f1fee865e7462c47fe73799b4c6ce54635d5046b
cp "$b/Image" "$b/initramfs.cpio.gz" "$pkg/"
cd "$pkg"
sha256sum Image board.dtb initramfs.cpio.gz > SHA256SUMS
tar -czf r154t-payload.tar.gz Image board.dtb initramfs.cpio.gz
sha256sum r154t-payload.tar.gz >> SHA256SUMS
cat SHA256SUMS
