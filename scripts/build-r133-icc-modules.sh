#!/usr/bin/env bash
set -euo pipefail
src=/root/tb371fc/linux-6.12-donor-r118
out=/root/tb371fc/build-6.12-r130-usb2-late
mod=/root/tb371fc/r133-icc-modules
pkg=/mnt/d/TB371FC-builds/r133-icc-modules
project="$(cd "$(dirname "$0")/.." && pwd)"
test ! -e "$mod"
test ! -e "$pkg"
grep -qx CONFIG_INTERCONNECT=y "$out/.config"
grep -qx CONFIG_QCOM_RPMH=y "$out/.config"
grep -qx CONFIG_QCOM_COMMAND_DB=y "$out/.config"
mkdir "$mod" "$pkg"
sha256sum "$src/drivers/interconnect/qcom/icc-common.c" "$src/drivers/interconnect/qcom/icc-rpmh.c" "$src/drivers/interconnect/qcom/bcm-voter.c" "$src/drivers/interconnect/qcom/sm8250.c" "$out/.config" "$out/arch/arm64/boot/Image" > "$pkg/source-before.sha256"
for name in icc-common icc-rpmh bcm-voter sm8250; do cp "$src/drivers/interconnect/qcom/$name.c" "$mod/"; done
cp "$src/drivers/interconnect/qcom/"*.h "$mod/"
cp "$project/scripts/r133-icc.Kbuild" "$mod/Kbuild"
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 -j4 M="$mod" modules > "$pkg/build.log" 2>&1
sha256sum -c "$pkg/source-before.sha256"
expected=$(modinfo -F vermagic /mnt/d/TB371FC-builds/r132-dispcc-module/dispcc-sm8250.ko)
for file in "$mod/"*.ko; do
    test "$(modinfo -F vermagic "$file")" = "$expected"
    cp "$file" "$pkg/"
    modinfo "$file" > "$pkg/$(basename "$file").modinfo.txt"
done
(cd "$pkg"; sha256sum *.ko > SHA256SUMS; tar -czf r133-icc-modules.tar.gz *.ko SHA256SUMS; cat SHA256SUMS)
