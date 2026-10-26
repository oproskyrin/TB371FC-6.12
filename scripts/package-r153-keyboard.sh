#!/usr/bin/env bash
# R153 payload: R140 Image + R153 DTB (touch, Wi-Fi, keyboard) + R152 initramfs.
set -euo pipefail
pkg=/mnt/d/TB371FC-builds/r153-keyboard
b=/mnt/d/TB371FC-builds/r152-wifi-autostart
(cd "$b"; grep -E " (Image|initramfs.cpio.gz)$" SHA256SUMS | sha256sum -c -)
test "$(sha256sum "$pkg/board.dtb" | cut -d' ' -f1)" = e336fb1f3b1f200264b09db4eea6c115ae2c1b07efb647f0fab85aac29ee9b21
cp "$b/Image" "$b/initramfs.cpio.gz" "$pkg/"
cd "$pkg"
sha256sum Image board.dtb initramfs.cpio.gz > SHA256SUMS
tar -czf r153-payload.tar.gz Image board.dtb initramfs.cpio.gz
sha256sum r153-payload.tar.gz >> SHA256SUMS
cat SHA256SUMS
