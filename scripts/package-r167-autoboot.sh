#!/usr/bin/env bash
# R167 payload: R166 DTB (no-map 0x1d0000000/64M kexec hole) + NetworkManager Wi-Fi, 75 C throttle, no screen lock. Formerly R164 payload: R159 audio Image + R164 DTB (cpufreq-hw, no CPU ICC) + qcom_tsens; R163b initramfs base. Formerly: R159 audio Image + R161 DTB + R159 initramfs extended with: optional read-only
# apps layer (tb371fc-linux/layers/r163-apps.img) in the R129 overlay, 1.5 GB RAM upper,
# boot-time audio (TFA9894, QS) and Wi-Fi bring-up, timezone, PipeWire speaker sink.
set -euo pipefail
p="$(cd "$(dirname "$0")/.." && pwd)"
a=/mnt/d/TB371FC-builds/r159-audio; s=/mnt/d/TB371FC-builds/r160-sound; t=/mnt/d/TB371FC-builds/r161-tfa
pkg=/mnt/d/TB371FC-builds/r167-autoboot
rm -rf "$pkg"; mkdir -p "$pkg"
(cd "$a"; grep -E " (Image|initramfs.cpio.gz)$" SHA256SUMS | sha256sum -c -)

test "$(sha256sum /mnt/d/TB371FC-builds/r166-memhole/board.dtb | cut -d" " -f1)" = d427da0e76737f1187614e6409095a42f0c535008016862c4d9c89934e8ad145
cp "$a/Image" /mnt/d/TB371FC-builds/r166-memhole/board.dtb "$pkg/"
kr=6.12.30-tb371fc-r159-audio+
mr=$(mktemp -d /root/tb371fc/r163-modroot.XXXXXX)
cp -a "$a/modroot/." "$mr/"; mkdir -p "$mr/lib/modules/$kr/extra"
cp "$a/clk-rpmh.ko" "$a/qcom_pd_mapper.ko" "$s/snd-soc-tb371fc.ko" "$s/tb371fc-lpass-vote.ko" "$t/snd-soc-tfa98xx.ko" /mnt/d/TB371FC-builds/r164-thermal/qcom_tsens.ko "$mr/lib/modules/$kr/extra/"
rm -f "$mr/lib/modules/$kr/build" "$mr/lib/modules/$kr/source"
depmod -b "$mr" "$kr"
for m in qcom_tsens clk-rpmh qcom_pd_mapper snd-soc-tb371fc tb371fc-lpass-vote snd-soc-tfa98xx qcom_q6v5_pas ath11k_pci; do modinfo -b "$mr" -k "$kr" -n $m >/dev/null; done
stage=$(mktemp -d /root/tb371fc/r163-initramfs.XXXXXX); echo "$stage" > "$pkg/staging-path.txt"
(cd "$stage"; gzip -dc "$a/initramfs.cpio.gz" | cpio -idmu --quiet)
tar -czf "$stage/r130-config/r163-modroot.tar.gz" -C "$mr" lib/modules
cp "$p"/scripts/r163-config/* "$stage/r130-config/"
cp /mnt/d/TB371FC-builds/private/r152-wpa.conf "$stage/r130-config/r163-wpa.conf"
# evidence chain: R163 setup after the sleep mask, before KDE starts
ev="$stage/r129-config/r129-evidence.sh"
grep -qx '/run/r130/busybox sh /run/r130/config/r158-install.sh' "$ev"
sed -i 's#^/run/r130/busybox sh /run/r130/config/r158-install.sh$#&\n/run/r130/busybox sh /run/r130/config/r163-install.sh#' "$ev"
sh -n "$ev"
# loader: optional apps layer + bigger RAM upper
python3 - "$stage/bin/boot-arch-r129-base" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
def rep(old, new):
    global s
    assert s.count(old) == 1, old
    s = s.replace(old, new)
rep('mount -t tmpfs -o size=512M,mode=0755 tmpfs "$base/rw" || rescue \'RAM upper mount failed\'\n',
    'lowerdirs="$base/lower"\n'
    '# R163: optional read-only apps layer from microSD (Chromium etc.), above the base image.\n'
    'apps_img=$base/sd/tb371fc-linux/layers/r163-apps.img\n'
    'if [ -f "$apps_img" ]; then\n'
    '\tmkdir -p "$base/apps"\n'
    '\t[ -b /dev/loop1 ] || "$bb" mknod -m 600 /dev/loop1 b 7 1\n'
    '\tif "$bb" losetup -r /dev/loop1 "$apps_img" && mount -t ext4 -o ro,noload /dev/loop1 "$base/apps" && [ -f "$base/apps/etc/tb371fc-r163-apps-layer" ]; then\n'
    '\t\tlowerdirs="$base/apps:$base/lower"; echo "R163: apps layer mounted"\n'
    '\telse\n'
    '\t\techo "R163: apps layer present but not usable, continuing without it"; umount "$base/apps" 2>/dev/null; "$bb" losetup -d /dev/loop1 2>/dev/null\n'
    '\tfi\n'
    'fi\n'
    'mount -t tmpfs -o size=1536M,mode=0755 tmpfs "$base/rw" || rescue \'RAM upper mount failed\'\n')
rep('-o "lowerdir=$base/lower,upperdir=', '-o "lowerdir=$lowerdirs,upperdir=')
open(p, 'w').write(s)
PY
sh -n "$stage/bin/boot-arch-r129-base"
grep -n "lowerdirs\|1536M" "$stage/bin/boot-arch-r129-base" | head
chmod 0755 "$stage"/r130-config/*.sh
(cd "$stage"; find . -print0 | sort -z | cpio --null -o --format=newc --owner=0:0 --quiet | gzip -9n) > "$pkg/initramfs.cpio.gz"
cd "$pkg"; sha256sum Image board.dtb initramfs.cpio.gz > SHA256SUMS
tar -czf r167-payload.tar.gz Image board.dtb initramfs.cpio.gz; sha256sum r167-payload.tar.gz >> SHA256SUMS
du -h initramfs.cpio.gz; cat SHA256SUMS
