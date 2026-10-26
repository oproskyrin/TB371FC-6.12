#!/usr/bin/env bash
# R161 payload: R159 Image + R161 DTB + R159 initramfs; /run extras incl. TFA98xx (MTP-guarded).
set -euo pipefail
a=/mnt/d/TB371FC-builds/r159-audio; s=/mnt/d/TB371FC-builds/r160-sound; pkg=/mnt/d/TB371FC-builds/r161-tfa
(cd "$a"; grep -E " (Image|initramfs.cpio.gz)$" SHA256SUMS | sha256sum -c -)
test "$(sha256sum "$pkg/board.dtb" | cut -d' ' -f1)" = 3ddc9d5856c9cd559752a3753190922fef0bafe3fc27694f57b0e16cf710c221
cp "$a/Image" "$a/initramfs.cpio.gz" "$pkg/"
cd "$pkg"
tar -czf r161-extra.tar.gz -C "$a" clk-rpmh.ko qcom_pd_mapper.ko -C "$s" snd-soc-tb371fc.ko snd-soc-spdif-tx.ko tb371fc-lpass-vote.ko pcm-steps -C "$pkg" snd-soc-tfa98xx.ko
sha256sum Image board.dtb initramfs.cpio.gz > SHA256SUMS
tar -czf r161t-payload.tar.gz Image board.dtb initramfs.cpio.gz
sha256sum r161t-payload.tar.gz r161-extra.tar.gz snd-soc-tfa98xx.ko >> SHA256SUMS
cat SHA256SUMS
