#!/usr/bin/env bash
# R159: unchanged upstream clk-rpmh.c as external module for the R159 kernel (as in R135).
set -euo pipefail
src=/root/tb371fc/linux-6.12-donor-r118
out=/root/tb371fc/build-6.12-r159-audio
pkg=/mnt/d/TB371FC-builds/r159-audio
m=/root/tb371fc/r159-clk-rpmh; rm -rf "$m"; mkdir -p "$m"
cp "$src/drivers/clk/qcom/clk-rpmh.c" "$m/"
echo 'obj-m += clk-rpmh.o' > "$m/Kbuild"
echo 'ccflags-y += -I$(srctree)/drivers/clk/qcom' >> "$m/Kbuild"
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 M="$m" modules > "$pkg/clk-rpmh-build.log" 2>&1 || { tail -20 "$pkg/clk-rpmh-build.log"; exit 1; }
modinfo -F vermagic "$m/clk-rpmh.ko"
cp "$m/clk-rpmh.ko" "$pkg/clk-rpmh.ko"
sha256sum "$src/drivers/clk/qcom/clk-rpmh.c" "$pkg/clk-rpmh.ko" "$pkg/Image"
