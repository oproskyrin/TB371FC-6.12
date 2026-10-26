#!/usr/bin/env bash
set -euo pipefail
project="$(cd "$(dirname "$0")/.." && pwd)"
donor=/root/tb371fc/linux-6.12-donor-r118
src=/root/tb371fc/linux-6.12-r134-panel
out=/root/tb371fc/build-6.12-r134-panel
pkg=/mnt/d/TB371FC-builds/linux-6.12-r134-panel
if [ "${1:-}" != --resume ]; then
    test ! -e "$src"
    test ! -e "$out"
    test ! -e "$pkg"
    mkdir "$out" "$pkg"
    sha256sum "$donor/drivers/gpu/drm/panel/panel-novatek-nt36523.c" /root/tb371fc/build-6.12-r130-usb2-late/.config /root/tb371fc/build-6.12-r130-usb2-late/arch/arm64/boot/Image > "$pkg/donor-before.sha256"
    cp -a --reflink=auto "$donor" "$src"
    cp "$project/mainline-port/backports/linux-6.12/panel-novatek-nt36523.c" "$src/drivers/gpu/drm/panel/"
    cp /root/tb371fc/build-6.12-r130-usb2-late/.config "$out/.config"
    "$src/scripts/config" --file "$out/.config" --set-str LOCALVERSION '-tb371fc-r134-panel' --enable BACKLIGHT_CLASS_DEVICE --module DRM_PANEL_NOVATEK_NT36523 --module SM_DISPCC_8250 --module INTERCONNECT_QCOM --module INTERCONNECT_QCOM_SM8250
    make -C "$src" O="$out" ARCH=arm64 LLVM=-18 olddefconfig > "$pkg/configure.log" 2>&1
fi
cp "$project/mainline-port/backports/linux-6.12/panel-novatek-nt36523.c" "$src/drivers/gpu/drm/panel/"
cp "$project/mainline-port/backports/linux-6.12/drm-panel-bridge.c" "$src/drivers/gpu/drm/bridge/panel.c"
python3 "$project/scripts/verify-mainline-panel-order.py" "$src" | tee "$pkg/panel-order.txt"
grep -qx CONFIG_BACKLIGHT_CLASS_DEVICE=y "$out/.config"
grep -qx CONFIG_DRM_PANEL_NOVATEK_NT36523=m "$out/.config"
grep -qx CONFIG_SM_DISPCC_8250=m "$out/.config"
grep -qx CONFIG_INTERCONNECT_QCOM_SM8250=m "$out/.config"
diff -u /root/tb371fc/build-6.12-r130-usb2-late/.config "$out/.config" > "$pkg/config.diff" || test "$?" = 1
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 -j8 Image > "$pkg/build.log" 2>&1
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 modules_prepare > "$pkg/modules-prepare.log" 2>&1
cp "$out/vmlinux.symvers" "$out/Module.symvers"
mkdir -p "$out/r134-selected" "$pkg/modules"
for group in drivers/usb/dwc3 drivers/phy/qualcomm drivers/clk/qcom drivers/interconnect/qcom drivers/gpu/drm/panel; do
    target="$out/r134-selected/$group"
    mkdir -p "$(dirname "$target")"
    [ -d "$target" ] || cp -a "$src/$group" "$target"
    make -C "$src" O="$out" ARCH=arm64 LLVM=-18 -j8 M="$target" modules > "$pkg/$(echo "$group" | tr / -).log" 2>&1
    find "$target" -maxdepth 1 -name '*.ko' -type f -exec cp '{}' "$pkg/modules/" \;
done
extra="$out/r134-extra"
mkdir -p "$extra"
cp "$project/mainline-port/backports/linux-6.12/tb371fc-ktz8866.c" "$extra/"
cp "$project/scripts/r134-backlight.Kbuild" "$extra/Kbuild"
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 -j4 M="$extra" modules > "$pkg/backlight-build.log" 2>&1
cp "$extra/tb371fc-ktz8866.ko" "$pkg/modules/"
cp "$out/arch/arm64/boot/Image" "$out/.config" "$out/System.map" "$pkg/"
for file in "$pkg/modules/"*.ko; do
    modinfo -F vermagic "$file"
done > "$pkg/vermagic.txt"
test "$(sort -u "$pkg/vermagic.txt" | wc -l)" -eq 1
sha256sum -c "$pkg/donor-before.sha256"
(cd "$pkg"; sha256sum Image .config System.map modules/*.ko > SHA256SUMS; cat SHA256SUMS)
