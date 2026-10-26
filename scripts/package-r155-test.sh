#!/usr/bin/env bash
# R155 test payload: R140 Image + R155 DTB (SD non-removable + DMA) + R152 initramfs.
set -euo pipefail
pkg=/mnt/d/TB371FC-builds/r155-sd-dma
b=/mnt/d/TB371FC-builds/r152-wifi-autostart
(cd "$b"; grep -E " (Image|initramfs.cpio.gz)$" SHA256SUMS | sha256sum -c -)
test "$(sha256sum "$pkg/board.dtb" | cut -d' ' -f1)" = cd060078142b95b360b0fc02e3d9d4c337854bf7afcc253838c38cc20fdb980d
cp "$b/Image" "$b/initramfs.cpio.gz" "$pkg/"
cd "$pkg"
sha256sum Image board.dtb initramfs.cpio.gz > SHA256SUMS
tar -czf r155t-payload.tar.gz Image board.dtb initramfs.cpio.gz
sha256sum r155t-payload.tar.gz >> SHA256SUMS
cat SHA256SUMS
