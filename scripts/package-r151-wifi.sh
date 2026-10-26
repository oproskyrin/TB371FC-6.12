#!/usr/bin/env bash
# R151 payload: R140 Image + R149b initramfs (touch/KDE autostart) + R151 Wi-Fi DTB.
set -euo pipefail
pkg=/mnt/d/TB371FC-builds/r151-wifi
b=/mnt/d/TB371FC-builds/r149b-autostart
(cd "$b"; grep -E " (Image|initramfs.cpio.gz)$" SHA256SUMS | sha256sum -c -)
test "$(sha256sum "$pkg/board.dtb" | cut -d' ' -f1)" = 1e6151687b740dd65a5a51e0a690b7f32ecc9399b868c238d8fae2f27776c5a6
cp "$b/Image" "$b/initramfs.cpio.gz" "$pkg/"
cd "$pkg"
tar -czf r151-payload.tar.gz Image board.dtb initramfs.cpio.gz
tar -czf r151-modules.tar.gz -C modules $(cd modules; ls *.ko)
sha256sum Image board.dtb initramfs.cpio.gz r151-payload.tar.gz r151-modules.tar.gz | tee SHA256SUMS
