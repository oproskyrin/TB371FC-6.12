#!/usr/bin/env bash
set -euo pipefail
src=/root/tb371fc/linux-6.12-donor-r118
out=/root/tb371fc/build-6.12-r130-usb2-late
mod=/root/tb371fc/r132-dispcc-module
pkg=/mnt/d/TB371FC-builds/r132-dispcc-module
project="$(cd "$(dirname "$0")/.." && pwd)"
test ! -e "$mod"
test ! -e "$pkg"
test -s "$out/Module.symvers"
test -s "$out/scripts/module.lds"
mkdir "$mod" "$pkg"
sha256sum "$src/drivers/clk/qcom/dispcc-sm8250.c" "$out/.config" "$out/arch/arm64/boot/Image" > "$pkg/source-before.sha256"
cp "$src/drivers/clk/qcom/dispcc-sm8250.c" "$mod/"
cp "$src/drivers/clk/qcom/"*.h "$mod/"
cp "$project/scripts/r132-dispcc.Kbuild" "$mod/Kbuild"
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 -j4 M="$mod" modules > "$pkg/build.log" 2>&1
sha256sum -c "$pkg/source-before.sha256"
test "$(modinfo -F vermagic "$mod/dispcc-sm8250.ko")" = "$(modinfo -F vermagic /mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r130-usb2-late/dwc3-qcom.ko)"
cp "$mod/dispcc-sm8250.ko" "$pkg/"
modinfo "$mod/dispcc-sm8250.ko" > "$pkg/modinfo.txt"
(cd "$pkg"; sha256sum dispcc-sm8250.ko > SHA256SUMS; cat SHA256SUMS)
