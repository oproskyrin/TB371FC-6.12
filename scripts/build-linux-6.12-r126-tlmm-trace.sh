#!/usr/bin/env bash
set -euo pipefail
src=/root/tb371fc/linux-6.12-donor-r126
out=/root/tb371fc/build-6.12-r126-tlmm-trace
pkg=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r126-tlmm-trace
test ! -e "$out"
test ! -e "$pkg"
grep -q 'R126 TLMM checkpoint' "$src/drivers/pinctrl/qcom/pinctrl-msm.c"
mkdir "$out" "$pkg"
cp /root/tb371fc/build-6.12-r118-pinctrl/.config "$out/.config"
"$src/scripts/config" --file "$out/.config" --set-str LOCALVERSION '-tb371fc-r126-tlmm-trace'
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 olddefconfig > "$pkg/configure.log" 2>&1
grep -qx CONFIG_PINCTRL_MSM=y "$out/.config"
grep -qx CONFIG_PINCTRL_SM8250=y "$out/.config"
git -C "$src" diff --check
git -C "$src" diff --binary > "$pkg/source.patch"
sha256sum "$src/drivers/pinctrl/qcom/pinctrl-msm.c" "$src/arch/arm64/kernel/setup.c" > "$pkg/source-before.sha256"
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 -j8 Image > "$pkg/compile.log" 2>&1
sha256sum -c "$pkg/source-before.sha256"
cp "$out/arch/arm64/boot/Image" "$out/System.map" "$out/.config" "$pkg/"
cp /mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r125-no-gpio75-hog/board.dtb "$pkg/board.dtb"
(cd "$pkg"; sha256sum Image board.dtb System.map .config source.patch > SHA256SUMS; cat SHA256SUMS)
