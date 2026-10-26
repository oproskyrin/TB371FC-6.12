#!/usr/bin/env bash
set -euo pipefail
src=/root/tb371fc/linux-6.12-donor-r118
out=/root/tb371fc/build-6.12-r130-usb2-late
pkg=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r130-usb2-late
if [ "${1:-}" = --finish-modules ]; then
    test -s "$out/vmlinux.symvers"
    test -s "$pkg/source-before.sha256"
else
    test ! -e "$out"
    test ! -e "$pkg"
    mkdir "$out" "$pkg"
    cp /root/tb371fc/build-6.12-r118-pinctrl/.config "$out/.config"
    "$src/scripts/config" --file "$out/.config" --set-str LOCALVERSION '-tb371fc-r130-usb2-late' --enable GENERIC_PHY --module USB_DWC3_QCOM --module PHY_QCOM_USB_SNPS_FEMTO_V2
    make -C "$src" O="$out" ARCH=arm64 LLVM=-18 olddefconfig > "$pkg/configure.log" 2>&1
    sha256sum "$src/arch/arm64/kernel/setup.c" "$src/drivers/usb/dwc3/dwc3-qcom.c" "$src/drivers/phy/qualcomm/phy-qcom-snps-femto-v2.c" > "$pkg/source-before.sha256"
    make -C "$src" O="$out" ARCH=arm64 LLVM=-18 -j8 Image > "$pkg/compile.log" 2>&1
fi
grep -qx CONFIG_GENERIC_PHY=y "$out/.config"
grep -qx CONFIG_USB_DWC3_QCOM=m "$out/.config"
grep -qx CONFIG_PHY_QCOM_USB_SNPS_FEMTO_V2=m "$out/.config"
test -s "$out/vmlinux.symvers"
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 modules_prepare > "$pkg/modules-prepare.log" 2>&1
cp "$out/vmlinux.symvers" "$out/Module.symvers"
mkdir -p "$out/module-src"
[ -d "$out/module-src/dwc3" ] || cp -a "$src/drivers/usb/dwc3" "$out/module-src/dwc3"
[ -d "$out/module-src/qualcomm" ] || cp -a "$src/drivers/phy/qualcomm" "$out/module-src/qualcomm"
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 -j8 M="$out/module-src/dwc3" modules > "$pkg/modules-dwc3.log" 2>&1
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 -j8 M="$out/module-src/qualcomm" modules > "$pkg/modules-phy.log" 2>&1
sha256sum -c "$pkg/source-before.sha256"
cp "$out/arch/arm64/boot/Image" "$out/System.map" "$out/.config" "$pkg/"
cp "$out/module-src/dwc3/dwc3-qcom.ko" "$out/module-src/qualcomm/phy-qcom-snps-femto-v2.ko" "$pkg/"
cp "$out/include/generated/utsrelease.h" "$pkg/"
(cd "$pkg"; sha256sum Image System.map .config *.ko > SHA256SUMS; cat SHA256SUMS)
