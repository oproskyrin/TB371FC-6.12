#!/usr/bin/env bash
# R177 payload: R177 kernel (sdhci-msm "tb371fc,io-pads-1v8": IO pads 1.8 V at probe) + DTB with
# microSD DMA at 50 MHz (+ that property) + R175 initramfs. read 21.2 MB/s, write 17.1 MB/s,
# 2 GiB write/verify stress clean (was 6.3/5.1 MB/s in PIO at 25 MHz).
set -euo pipefail
src=/mnt/d/TB371FC-builds/r175-autoboot; pkg=/mnt/d/TB371FC-builds/r177-autoboot
rm -rf "$pkg"; mkdir -p "$pkg"
(cd "$src"; grep -E " initramfs.cpio.gz$" SHA256SUMS | sha256sum -c -)
test "$(sha256sum /mnt/d/TB371FC-builds/r177-kernel/Image | cut -d' ' -f1)" = 55fcf49e30a4abbe564cc17e255e107947346c7895016e2eb200011fdd117c0d
test "$(sha256sum /mnt/d/TB371FC-builds/r176-sd-speed/board-dma50p.dtb | cut -d' ' -f1)" = 635df17d4baed1046c9c21453021227fb1b2bbd8599a8a44a6bf706e231d36f8
cp /mnt/d/TB371FC-builds/r177-kernel/Image "$src/initramfs.cpio.gz" "$pkg/"; cp /mnt/d/TB371FC-builds/r176-sd-speed/board-dma50p.dtb "$pkg/board.dtb"
cd "$pkg"; sha256sum Image board.dtb initramfs.cpio.gz > SHA256SUMS
tar -czf r177-payload.tar.gz Image board.dtb initramfs.cpio.gz; sha256sum r177-payload.tar.gz >> SHA256SUMS; cat SHA256SUMS
