#!/usr/bin/env bash
# R168t test payload: R167 Image/initramfs + R168 DTB (non-removable microSD).
set -euo pipefail
a=/mnt/d/TB371FC-builds/r167-autoboot; pkg=/mnt/d/TB371FC-builds/r168-sdfix
(cd "$a"; grep -E " (Image|initramfs.cpio.gz)$" SHA256SUMS | sha256sum -c -)
test "$(sha256sum "$pkg/board.dtb" | cut -d' ' -f1)" = 99d1cb233d6ca3c14cd21318aa45a62054c39abc11f544fcb703070d3cd5f5a9
cp "$a/Image" "$a/initramfs.cpio.gz" "$pkg/"
cd "$pkg"; sha256sum Image board.dtb initramfs.cpio.gz > SHA256SUMS
tar -czf r168t-payload.tar.gz Image board.dtb initramfs.cpio.gz; sha256sum r168t-payload.tar.gz >> SHA256SUMS; cat SHA256SUMS
