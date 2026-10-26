#!/usr/bin/env bash
# R146: R144 kernel + 7.1 single-CTL model for active-CTL DPU (one logical change).
# LOCALVERSION is unchanged so the R139 initramfs modules (same vermagic) load.
set -euo pipefail
project="$(cd "$(dirname "$0")/.." && pwd)"
basesrc=/root/tb371fc/linux-6.12-r144-dsc-width
baseout=/root/tb371fc/build-6.12-r144-dsc-width
src=/root/tb371fc/linux-6.12-r146-single-ctl
out=/root/tb371fc/build-6.12-r146-single-ctl
pkg=/mnt/d/TB371FC-builds/r146-single-ctl
patch="$project/mainline-port/backports/linux-6.12/0010-dpu-dsc-keep-bonded-intf-count.patch"
if [ "${1:-}" != --resume ]; then
    test ! -e "$src"; test ! -e "$out"; test ! -e "$pkg"
    mkdir -p "$pkg"
    cp -a --reflink=auto "$basesrc" "$src"
    cp -a --reflink=auto "$baseout" "$out"
    python3 "$project/scripts/apply-r146-single-ctl.py" "$src"
fi
grep -q "topology.num_intf = intf_count;" "$src/drivers/gpu/drm/msm/disp/dpu1/dpu_encoder.c"; grep -q "timing->width = DIV_ROUND_UP(timing->width" "$src/drivers/gpu/drm/msm/disp/dpu1/dpu_encoder_phys_vid.c"; grep -q "R146 single CTL" "$src/drivers/gpu/drm/msm/disp/dpu1/dpu_rm.c"; ! grep -q "each CTL owns only its own DSC" "$src/drivers/gpu/drm/msm/disp/dpu1/dpu_encoder.c"
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 -j8 Image > "$pkg/build.log" 2>&1
cp "$out/arch/arm64/boot/Image" "$pkg/Image"
old=$(grep -a -o -m1 "Linux version 6.12.30-tb371fc-r137-native+ " /mnt/d/TB371FC-builds/r141-dpu-only/Image | head -1 || true)
new=$(grep -a -o -m1 "Linux version 6.12.30-tb371fc-r137-native+ " "$pkg/Image" | head -1 || true)
test -n "$old"; test "$old" = "$new"
cp /mnt/d/TB371FC-builds/r141-dpu-only/board.dtb /mnt/d/TB371FC-builds/r141-dpu-only/initramfs.cpio.gz "$pkg/"
cp "$patch" "$pkg/"
(cd "$src"; git diff -- drivers/gpu/drm/msm/disp/dpu1/) > "$pkg/dpu1.diff"
cd "$pkg"
sha256sum Image board.dtb initramfs.cpio.gz > SHA256SUMS
tar -czf r146-payload.tar.gz Image board.dtb initramfs.cpio.gz
sha256sum r146-payload.tar.gz >> SHA256SUMS
cat SHA256SUMS
tail -3 build.log
