#!/usr/bin/env bash
# R157 payload: R140 Image + R153 DTB (touch, keyboard; Wi-Fi nodes present but no modules
# loaded) + R149b initramfs (touch/KDE autostart, NO Wi-Fi autostart).
set -euo pipefail
pkg=/mnt/d/TB371FC-builds/r157-stable
test ! -e "$pkg/r157-payload.tar.gz"; mkdir -p "$pkg"
(cd /mnt/d/TB371FC-builds/r149b-autostart; grep -E " (Image|initramfs.cpio.gz)$" SHA256SUMS | sha256sum -c -)
test "$(sha256sum /mnt/d/TB371FC-builds/r153-keyboard/board.dtb | cut -d' ' -f1)" = e336fb1f3b1f200264b09db4eea6c115ae2c1b07efb647f0fab85aac29ee9b21
cp /mnt/d/TB371FC-builds/r149b-autostart/Image /mnt/d/TB371FC-builds/r149b-autostart/initramfs.cpio.gz /mnt/d/TB371FC-builds/r153-keyboard/board.dtb "$pkg/"
cd "$pkg"; sha256sum Image board.dtb initramfs.cpio.gz > SHA256SUMS
tar -czf r157-payload.tar.gz Image board.dtb initramfs.cpio.gz; sha256sum r157-payload.tar.gz >> SHA256SUMS; cat SHA256SUMS
