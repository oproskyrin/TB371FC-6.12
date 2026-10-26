#!/usr/bin/env bash
# R160 test payload: R159 Image + R160 DTB + R159 initramfs; plus /run module set.
set -euo pipefail
a=/mnt/d/TB371FC-builds/r159-audio
pkg=/mnt/d/TB371FC-builds/r160-sound
(cd "$a"; grep -E " (Image|initramfs.cpio.gz)$" SHA256SUMS | sha256sum -c -)
test "$(sha256sum "$pkg/board.dtb" | cut -d' ' -f1)" = 65b38f144138bf73de6cd1a2b3239f3e88ada9ce5d5e4e1aa941739945a488c3
cp "$a/Image" "$a/initramfs.cpio.gz" "$pkg/"
cd "$pkg"
tar -czf r160-extra.tar.gz -C "$a" clk-rpmh.ko qcom_pd_mapper.ko -C "$pkg" snd-soc-tb371fc.ko snd-soc-spdif-tx.ko
sha256sum Image board.dtb initramfs.cpio.gz > SHA256SUMS
tar -czf r160t-payload.tar.gz Image board.dtb initramfs.cpio.gz
sha256sum r160t-payload.tar.gz r160-extra.tar.gz "$a/r159-modroot.tar.gz" >> SHA256SUMS
cat SHA256SUMS
