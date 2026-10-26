#!/usr/bin/env bash
set -euo pipefail
project="$(cd "$(dirname "$0")/.." && pwd)"
src=/root/tb371fc/linux-6.12-r134-panel
out=/root/tb371fc/build-6.12-r134-panel
pkg=/mnt/d/TB371FC-builds/r135-rpmh-clock
test ! -e "$pkg"
mkdir "$pkg"
extra=$(mktemp -d /root/tb371fc/r135-rpmh-clock.XXXXXX)
sha256sum "$out/.config" "$out/arch/arm64/boot/Image" > "$pkg/kernel-before.sha256"
cp "$src/drivers/clk/qcom/clk-rpmh.c" "$extra/"
cp "$project/scripts/r135-rpmh-clock.Kbuild" "$extra/Kbuild"
test -s "$out/Module.symvers"
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 -j4 M="$extra" modules > "$pkg/build.log" 2>&1
cp "$extra/clk-rpmh.ko" "$extra/clk-rpmh.c" "$pkg/"
modinfo "$pkg/clk-rpmh.ko" > "$pkg/modinfo.txt"
modinfo -F vermagic "$pkg/clk-rpmh.ko" | grep -q '^6.12.30-tb371fc-r134-panel+ '
sha256sum -c "$pkg/kernel-before.sha256"
(cd "$pkg"; sha256sum clk-rpmh.ko clk-rpmh.c > SHA256SUMS; cat SHA256SUMS)
