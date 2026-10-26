#!/usr/bin/env bash
# R170t test payload: R169 Image/initramfs + R170 DTB (I2C5/I2C11 + dual KTZ8866 backlight).
set -euo pipefail
a=/mnt/d/TB371FC-builds/r169-autoboot; pkg=/mnt/d/TB371FC-builds/r170-backlight
(cd "$a"; grep -E " (Image|initramfs.cpio.gz)$" SHA256SUMS | sha256sum -c -)
test "$(sha256sum "$pkg/board.dtb" | cut -d' ' -f1)" = a99cb12414292f886bd30f2ab31652ed8d92996d2224cfbd4d36dc43e2888655
cp "$a/Image" "$a/initramfs.cpio.gz" "$pkg/"
cd "$pkg"; sha256sum Image board.dtb initramfs.cpio.gz > SHA256SUMS
tar -czf r170t-payload.tar.gz Image board.dtb initramfs.cpio.gz; sha256sum r170t-payload.tar.gz >> SHA256SUMS; cat SHA256SUMS
