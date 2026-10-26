#!/usr/bin/env bash
# R160b payload: R159 Image + R160b DTB + R159 initramfs; /run extras incl. fixed machine driver.
set -euo pipefail
a=/mnt/d/TB371FC-builds/r159-audio; s=/mnt/d/TB371FC-builds/r160-sound; pkg=/mnt/d/TB371FC-builds/r160b-sound
(cd "$a"; grep -E " (Image|initramfs.cpio.gz)$" SHA256SUMS | sha256sum -c -)
test "$(sha256sum "$pkg/board.dtb" | cut -d' ' -f1)" = b9aafdb76e567306fb14fffb0b4cc010bb1b8880f864e3dd60ce08d523fd160d
cp "$a/Image" "$a/initramfs.cpio.gz" "$pkg/"
cd "$pkg"
tar -czf r160b-extra.tar.gz -C "$a" clk-rpmh.ko qcom_pd_mapper.ko -C "$s" snd-soc-tb371fc.ko snd-soc-spdif-tx.ko tb371fc-lpass-vote.ko pcm-steps
sha256sum Image board.dtb initramfs.cpio.gz > SHA256SUMS
tar -czf r160bt-payload.tar.gz Image board.dtb initramfs.cpio.gz
sha256sum r160bt-payload.tar.gz r160b-extra.tar.gz "$s/snd-soc-tb371fc.ko" >> SHA256SUMS
cat SHA256SUMS
