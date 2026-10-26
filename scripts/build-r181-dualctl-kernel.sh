#!/usr/bin/env bash
# R181: R180 native tree with the R144 dual-CTL DPU model (R144 showed a correct LEFT half) instead of
# the R146 single-CTL files, plus the DSC initial_lines vendor formula. Same kernel.release.
set -euo pipefail
p="$(cd "$(dirname "$0")/.." && pwd)"
r180=/root/tb371fc/linux-6.12-r180-native; o180=/root/tb371fc/build-6.12-r180-native
src=/root/tb371fc/linux-6.12-r181-dualctl; out=/root/tb371fc/build-6.12-r181-dualctl
r144=/root/tb371fc/linux-6.12-r144-dsc-width
pkg=/mnt/d/TB371FC-builds/r181-dualctl; mkdir -p "$pkg"
[ -d "$src" ] || cp -a "$r180" "$src"
[ -d "$out" ] || { cp -a "$o180" "$out"; sed -i "s#$r180#$src#g" "$out/Makefile"; }
for f in dpu_encoder.c dpu_encoder_phys_vid.c dpu_hw_ctl.c dpu_hw_ctl.h dpu_rm.c dpu_rm.h; do
  cp "$r144/drivers/gpu/drm/msm/disp/dpu1/$f" "$src/drivers/gpu/drm/msm/disp/dpu1/$f"
done
python3 "$p/scripts/r180-dsc-initial-lines.py" "$src/drivers/gpu/drm/msm/disp/dpu1/dpu_encoder.c"
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 -j"$(nproc)" Image > "$pkg/build.log" 2>&1 || { grep -E "error" "$pkg/build.log" | head; exit 1; }
grep -E "^\s+CC" "$pkg/build.log"
cp "$out/arch/arm64/boot/Image" "$pkg/"
cp /mnt/d/TB371FC-builds/r180-native/board.dtb /mnt/d/TB371FC-builds/r180-native/initramfs.cpio.gz "$pkg/"
cd "$pkg"; sha256sum Image board.dtb initramfs.cpio.gz > SHA256SUMS; tar -czf r181-payload.tar.gz Image board.dtb initramfs.cpio.gz; cat SHA256SUMS
