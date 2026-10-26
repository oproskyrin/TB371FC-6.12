#!/usr/bin/env bash
set -euo pipefail
project="$(cd "$(dirname "$0")/.." && pwd)"
base=/root/tb371fc/linux-6.12-r134-panel
baseout=/root/tb371fc/build-6.12-r134-panel
src=/root/tb371fc/linux-6.12-r137-native
out=/root/tb371fc/build-6.12-r137-native
pkg=/mnt/d/TB371FC-builds/r137-native-prereqs
if [ "${1:-}" != --resume ]; then
    test ! -e "$src"; test ! -e "$out"; test ! -e "$pkg"
    mkdir "$pkg"
    sha256sum "$baseout/.config" "$baseout/arch/arm64/boot/Image" > "$pkg/base-before.sha256"
    cp -a --reflink=auto "$base" "$src"
    cp -a --reflink=auto "$baseout" "$out"
fi
if [ ! -e "$pkg/prepared.ok" ]; then
    git -C "$src" apply --recount --check "$project/mainline-port/backports/linux-6.12/0002-tb371fc-phy-wideplane.patch"
    git -C "$src" apply --recount "$project/mainline-port/backports/linux-6.12/0002-tb371fc-phy-wideplane.patch"
    "$src/scripts/config" --file "$out/.config" --set-str LOCALVERSION '-tb371fc-r137-native' --module QCOM_CLK_RPMH
    make -C "$src" O="$out" ARCH=arm64 LLVM=-18 olddefconfig > "$pkg/configure.log" 2>&1
    touch "$pkg/prepared.ok"
fi
if ! grep -q 'Exact working4.19 V56 DPHY values' "$src/drivers/gpu/drm/msm/dsi/phy/dsi_phy_7nm.c"; then
    git -C "$src" apply --recount "$project/mainline-port/backports/linux-6.12/0003-tb371fc-v56-analog.patch"
fi
"$src/scripts/config" --file "$out/.config" --module REGULATOR_QCOM_RPMH
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 olddefconfig > "$pkg/configure-power.log" 2>&1
python3 "$project/scripts/verify-r137-native-prereqs.py" "$src" > "$pkg/native-source-qa.txt"
python3 "$project/scripts/verify-mainline-panel-order.py" "$src" > "$pkg/panel-order.txt"
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 -j8 Image > "$pkg/build.log" 2>&1
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 modules_prepare > "$pkg/modules-prepare.log" 2>&1
cp "$out/vmlinux.symvers" "$out/Module.symvers"
mkdir -p "$out/r137-selected" "$pkg/modules"
for group in drivers/usb/dwc3 drivers/phy/qualcomm drivers/clk/qcom drivers/interconnect/qcom drivers/gpu/drm/panel drivers/regulator; do
    target="$out/r137-selected/$group"
    mkdir -p "$(dirname "$target")"
    [ -d "$target" ] || cp -a "$src/$group" "$target"
    make -C "$src" O="$out" ARCH=arm64 LLVM=-18 -j8 M="$target" modules > "$pkg/$(echo "$group" | tr / -).log" 2>&1
    find "$target" -maxdepth 1 -name '*.ko' -type f -exec cp '{}' "$pkg/modules/" \;
done
extra="$out/r137-backlight"
mkdir -p "$extra"
cp "$project/mainline-port/backports/linux-6.12/tb371fc-ktz8866.c" "$extra/"
cp "$project/scripts/r134-backlight.Kbuild" "$extra/Kbuild"
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 -j4 M="$extra" modules > "$pkg/backlight-build.log" 2>&1
cp "$extra/tb371fc-ktz8866.ko" "$pkg/modules/"
cp "$out/arch/arm64/boot/Image" "$out/.config" "$out/System.map" "$pkg/"
for file in "$pkg/modules/"*.ko; do modinfo -F vermagic "$file"; done > "$pkg/vermagic.txt"
test "$(sort -u "$pkg/vermagic.txt" | wc -l)" -eq 1
grep -q '^6.12.30-tb371fc-r137-native+ ' "$pkg/vermagic.txt"
test "$(find "$pkg/modules" -name '*.ko' | wc -l)" -eq 11
sha256sum -c "$pkg/base-before.sha256"
(cd "$pkg"; sha256sum Image .config System.map modules/*.ko > SHA256SUMS; cat SHA256SUMS)
