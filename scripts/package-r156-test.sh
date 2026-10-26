#!/usr/bin/env bash
# R156 test payload: R140 Image + R156 DTB (SD non-removable + DMA + rpmh SD rails) + R152 initramfs.
set -euo pipefail
pkg=/mnt/d/TB371FC-builds/r156-sd-power
b=/mnt/d/TB371FC-builds/r152-wifi-autostart
(cd "$b"; grep -E " (Image|initramfs.cpio.gz)$" SHA256SUMS | sha256sum -c -)
test "$(sha256sum "$pkg/board.dtb" | cut -d' ' -f1)" = 5c05eea53b70888e5b0bbe70faa47d45d432ca5d5e85eb3e6d4f783d33abe21a
cp "$b/Image" "$b/initramfs.cpio.gz" "$pkg/"
cd "$pkg"
sha256sum Image board.dtb initramfs.cpio.gz > SHA256SUMS
tar -czf r156t-payload.tar.gz Image board.dtb initramfs.cpio.gz
sha256sum r156t-payload.tar.gz >> SHA256SUMS
cat SHA256SUMS
