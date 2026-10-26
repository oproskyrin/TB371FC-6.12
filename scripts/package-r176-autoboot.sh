#!/usr/bin/env bash
# R176 payload: R175 Image + initramfs (841ebcb0) + DTB with microSD DMA (ADMA 64-bit via
# apps_smmu 0x4a0, no sdhci-caps-mask) at 25 MHz: read 6.3 -> 10.3 MB/s, write 5.1 -> 9.0 MB/s,
# 2 GiB write/verify stress clean. 50 MHz with DMA fails at probe (pads still in 3.0 V mode then).
set -euo pipefail
src=/mnt/d/TB371FC-builds/r175-autoboot; pkg=/mnt/d/TB371FC-builds/r176-autoboot
rm -rf "$pkg"; mkdir -p "$pkg"
(cd "$src"; grep -E " (Image|initramfs.cpio.gz)$" SHA256SUMS | sha256sum -c -)
test "$(sha256sum /mnt/d/TB371FC-builds/r176-sd-speed/board-dma25.dtb | cut -d' ' -f1)" = dbb4494fe2a2574f99cdca7318b896bb26d5926e40f1cea5fa1389ee3f4e08db
cp "$src/Image" "$src/initramfs.cpio.gz" "$pkg/"; cp /mnt/d/TB371FC-builds/r176-sd-speed/board-dma25.dtb "$pkg/board.dtb"
cd "$pkg"; sha256sum Image board.dtb initramfs.cpio.gz > SHA256SUMS
tar -czf r176-payload.tar.gz Image board.dtb initramfs.cpio.gz; sha256sum r176-payload.tar.gz >> SHA256SUMS; cat SHA256SUMS
