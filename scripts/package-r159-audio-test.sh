#!/usr/bin/env bash
# R159 test payload: R159 Image + R153/R158 DTB + R158 initramfs whose boot-time modules
# (USB PHY/DWC3, NT36523 touch) are replaced by builds for the R159 kernel.
# Also produces r159-mods.tar.gz (audio/remoteproc/Wi-Fi/regulator modules + deps) for /run.
set -euo pipefail
project="$(cd "$(dirname "$0")/.." && pwd)"
src=/root/tb371fc/linux-6.12-donor-r118
out=/root/tb371fc/build-6.12-r159-audio
pkg=/mnt/d/TB371FC-builds/r159-audio
b=/mnt/d/TB371FC-builds/r158-nosleep
kr=$(cat "$out/include/config/kernel.release")
mr="$pkg/modroot/lib/modules/$kr"
test -d "$mr"
# touch driver (external, patch 0002) for the new kernel
tm=/root/tb371fc/r159-nt36523-module; rm -rf "$tm"; mkdir -p "$tm"
cp /root/tb371fc/r148-nt36523-module/*.[ch] /root/tb371fc/r148-nt36523-module/Kbuild "$tm/"
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 M="$tm" modules > "$pkg/touch-build.log" 2>&1
test "$(modinfo -F vermagic "$tm/nt36523_ts.ko" | cut -d' ' -f1)" = "$kr"
(cd "$b"; grep -E " (board.dtb|initramfs.cpio.gz)$" SHA256SUMS | sha256sum -c -)
cp "$b/board.dtb" "$pkg/board.dtb"
stage=$(mktemp -d /root/tb371fc/r159-initramfs.XXXXXX); echo "$stage" > "$pkg/staging-path.txt"
(cd "$stage"; gzip -dc "$b/initramfs.cpio.gz" | cpio -idmu --quiet)
for m in dwc3-qcom phy-qcom-snps-femto-v2; do
    f=$(find "$mr" -name "$m.ko*" | head -1); test -n "$f"
    case "$f" in *.ko.zst) zstd -dq "$f" -o "$stage/r130-modules/$m.ko" -f ;; *.ko.xz) xz -dc "$f" > "$stage/r130-modules/$m.ko" ;; *) cp "$f" "$stage/r130-modules/$m.ko" ;; esac
done
cp "$tm/nt36523_ts.ko" "$stage/r130-modules/nt36523_ts.ko"
for f in "$stage"/r130-modules/*.ko; do test "$(modinfo -F vermagic "$f" | cut -d' ' -f1)" = "$kr" || { echo "VERMAGIC $f"; exit 1; }; done
(cd "$stage"; find . -print0 | sort -z | cpio --null -o --format=newc --owner=0:0 --quiet | gzip -9n) > "$pkg/initramfs.cpio.gz"
# loadable module tree for /run (depmod'ed copy, only what audio/Wi-Fi/regulators need is used)
tar -czf "$pkg/r159-modroot.tar.gz" -C "$pkg/modroot" lib/modules
cd "$pkg"
sha256sum Image board.dtb initramfs.cpio.gz > SHA256SUMS
tar -czf r159t-payload.tar.gz Image board.dtb initramfs.cpio.gz
sha256sum r159t-payload.tar.gz r159-modroot.tar.gz >> SHA256SUMS
cat SHA256SUMS; du -h r159-modroot.tar.gz
