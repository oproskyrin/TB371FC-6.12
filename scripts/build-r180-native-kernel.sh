#!/usr/bin/env bash
# R180 native display kernel: the production tree (R177 sdhci pads + R179 headless GPU patches) with
# the R146 native display files (DPU single-CTL/DSC intf fixes + tb371fc catalog, DSI PHY lane
# config, panel bridge prepare_prev_first, NT36532 panel). Same kernel.release as R159/R177, so
# every production module still loads. External modules: dispcc-sm8250, panel-novatek-nt36523.
set -euo pipefail
base=/root/tb371fc/linux-6.12-donor-r118; bout=/root/tb371fc/build-6.12-r159-audio
src=/root/tb371fc/linux-6.12-r180-native; out=/root/tb371fc/build-6.12-r180-native
r146=/root/tb371fc/linux-6.12-r146-single-ctl
pkg=/mnt/d/TB371FC-builds/r180-native; mkdir -p "$pkg"
if [ ! -d "$src" ]; then cp -a "$base" "$src"; fi
if [ ! -d "$out" ]; then cp -a "$bout" "$out"; sed -i "s#$base#$src#g" "$out/Makefile"; fi
for f in $(cd "$r146" && ls drivers/gpu/drm/msm/disp/dpu1/*.[ch] drivers/gpu/drm/msm/disp/dpu1/catalog/dpu_6_0_sm8250.h drivers/gpu/drm/msm/dsi/phy/dsi_phy.[ch] drivers/gpu/drm/msm/dsi/phy/dsi_phy_7nm.c drivers/gpu/drm/bridge/panel.c drivers/gpu/drm/panel/panel-novatek-nt36523.c); do
  cmp -s "$r146/$f" "$src/$f" || { cp "$r146/$f" "$src/$f"; echo "R146 -> $f"; }
done
grep -q "tb371fc,headless-gpu" "$src/drivers/gpu/drm/msm/msm_drv.c"
# R180 fixes on top of the R146 files
grep -q Hardent "$src/drivers/gpu/drm/msm/disp/dpu1/dpu_encoder.c" || python3 "$(cd "$(dirname "$0")/.." && pwd)/scripts/r180-dsc-initial-lines.py" "$src/drivers/gpu/drm/msm/disp/dpu1/dpu_encoder.c"
grep -q "tb371fc,io-pads-1v8" "$src/drivers/mmc/host/sdhci-msm.c"
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 -j"$(nproc)" Image > "$pkg/build.log" 2>&1 || { grep -E "error" "$pkg/build.log" | head; tail -20 "$pkg/build.log"; exit 1; }
cat "$out/include/config/kernel.release"
cp "$out/arch/arm64/boot/Image" "$pkg/Image"
# external modules
ext() { # name file include-dir [extra ccflags]
  m=/root/tb371fc/r180-ext-$1; rm -rf "$m"; mkdir -p "$m"; cp "$src/$2" "$m/"
  printf 'obj-m := %s.o
ccflags-y := -I$(srctree)/%s %s
' "$1" "$3" "${4:-}" > "$m/Kbuild"
  make -C "$src" O="$out" ARCH=arm64 LLVM=-18 M="$m" KBUILD_EXTRA_SYMBOLS=/root/tb371fc/r170-ktz8866/Module.symvers modules > "$pkg/$1.log" 2>&1 || { grep -E "error|WARNING" "$pkg/$1.log" | head; exit 1; }
  grep -E "WARNING" "$pkg/$1.log" || true
  cp "$m/$1.ko" "$pkg/"
}
ext dispcc-sm8250 drivers/clk/qcom/dispcc-sm8250.c drivers/clk/qcom
f=$src/drivers/gpu/drm/panel/panel-novatek-nt36523.c; [ -f $f.r146 ] || cp $f $f.r146; cp $f.r146 $f; python3 "$(cd "$(dirname "$0")/.." && pwd)/scripts/r180-panel-keep-splash.py" $f
ext panel-novatek-nt36523 drivers/gpu/drm/panel/panel-novatek-nt36523.c drivers/gpu/drm/panel -DCONFIG_BACKLIGHT_CLASS_DEVICE_MODULE=1
for m in "$pkg"/*.ko; do echo "$(basename $m): $(modinfo -F vermagic $m) deps=$(modinfo -F depends $m)"; done
sha256sum "$pkg/Image" "$pkg"/*.ko
