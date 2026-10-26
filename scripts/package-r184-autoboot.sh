#!/usr/bin/env bash
# R184 payload: R178 Image + R178 initramfs + R184 DTB (i2c3 enabled, GPIO 119/120 freed, MM8013 battery
# fuel gauge at 0x55). mm8013.ko, the zram swap and the upower override live on the persistent root.
set -euo pipefail
a=/mnt/d/TB371FC-builds/r178-autoboot; pkg=/mnt/d/TB371FC-builds/r184-autoboot
rm -rf "$pkg"; mkdir -p "$pkg"
cp "$a/Image" "$a/initramfs.cpio.gz" "$pkg/"; cp /mnt/d/TB371FC-builds/r184-battery/board.dtb "$pkg/board.dtb"
cd "$pkg"; sha256sum Image board.dtb initramfs.cpio.gz | tee SHA256SUMS
grep -q 55fcf49e30a4abbe564cc17e255e107947346c7895016e2eb200011fdd117c0d SHA256SUMS
grep -q 33eaf41be0dda8c77f5c465a7e521aeade1dd9830563bade7535c49f5689f1b4 SHA256SUMS
grep -q 291258e8d4dd2e16b343988a7df9565555c03dd9e12ff1ce198d641a83d4db3a SHA256SUMS
tar -czf r184-payload.tar.gz Image board.dtb initramfs.cpio.gz; ls -la
