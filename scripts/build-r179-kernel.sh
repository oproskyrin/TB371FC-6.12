#!/usr/bin/env bash
# R179 kernel: R177 kernel + adreno "tb371fc,headless-gpu" (Adreno 650 render node without MDSS).
set -euo pipefail
p="$(cd "$(dirname "$0")/.." && pwd)"
src=/root/tb371fc/linux-6.12-donor-r118; out=/root/tb371fc/build-6.12-r159-audio
pkg=/mnt/d/TB371FC-builds/r179-kernel; mkdir -p "$pkg"
f=$src/drivers/mmc/host/sdhci-msm.c
[ -f "$f.orig-r159" ] || cp "$f" "$f.orig-r159"
grep -q 'tb371fc,io-pads-1v8' "$f" || patch -p1 -d "$src" < "$p/mainline-port/patches/0002-mmc-sdhci-msm-tb371fc-io-pads-1v8-at-probe.patch"
grep -q "tb371fc,headless-gpu" "$src/drivers/gpu/drm/msm/adreno/adreno_device.c" || patch -p1 -d "$src" < "$p/mainline-port/patches/0003-drm-msm-adreno-tb371fc-headless-gpu.patch"
grep -q "tb371fc,headless-gpu" "$src/drivers/gpu/drm/msm/msm_drv.c"
cat "$out/include/config/kernel.release"
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 -j"$(nproc)" Image > "$pkg/build.log" 2>&1 || { tail -30 "$pkg/build.log"; exit 1; }
grep -E "warning|error" "$pkg/build.log" | grep -i sdhci || true
cat "$out/include/config/kernel.release"
cp "$out/arch/arm64/boot/Image" "$pkg/Image"; sha256sum "$pkg/Image"
