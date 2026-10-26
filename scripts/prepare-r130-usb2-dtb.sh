#!/usr/bin/env bash
set -euo pipefail
base=/mnt/d/TB371FC-builds/checkpoints/r129-arch612-headless-20261024/board.dtb
pkg=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r130-usb2-late
dtb=$pkg/board.dtb
wrapper=/soc/usb@a6f8800
core=$wrapper/usb@a600000
phy=/soc/phy@88e3000
printf '%s  %s\n' 0e312dab299e034b056e1e2e6550c7726415bf6a161cf074bc1f077c6432f828 "$base" | sha256sum -c -
test -d "$pkg"
test ! -e "$dtb"
cp "$base" "$dtb"
fdtput -t s "$dtb" "$wrapper" status okay
fdtput "$dtb" "$wrapper" qcom,select-utmi-as-pipe-clk
# Avoid populate -> unavailable ICC -> depopulate -> reprobe loops.
fdtput -d "$dtb" "$wrapper" interconnects
fdtput -d "$dtb" "$wrapper" interconnect-names
fdtput -t s "$dtb" "$core" dr_mode peripheral
fdtput -t s "$dtb" "$core" maximum-speed high-speed
fdtput -t s "$dtb" "$core" phy-names usb2-phy
hs=$(fdtget -t x "$dtb" "$phy" phandle)
fdtput -t x "$dtb" "$core" phys "$hs"
fdtput -d "$dtb" "$core" usb-role-switch
fdtput -r "$dtb" "$core/ports"
# Keep the existing IOMMU assignment; do not infer an IOMMU defect from logs.
test "$(fdtget -t x "$dtb" "$core" iommus)" = '31 0 0'
xo=$(fdtget -t x "$dtb" /clocks/tb371fc-inherited-cxo-div2 phandle)
fdtput -t x "$dtb" "$phy" clocks "$xo"
for supply in vdda-pll-supply vdda18-supply vdda33-supply; do
    fdtput -d "$dtb" "$phy" "$supply"
done
# PHY uses dummy regulators, inheriting the rails active in the 4.19 USB stage.
# USB3 is not part of this high-speed-only experiment.
fdtput -t s "$dtb" /soc/phy@88e8000 status disabled
test "$(fdtget -t s "$dtb" /soc/ufshc@1d84000 status)" = disabled
test "$(fdtget -t i "$dtb" /soc/pinctrl@f100000 gpio-reserved-ranges)" = '0 75 76 105'
dtc -q -I dtb -O dts "$base" > "$pkg/base-r129.dts"
dtc -q -I dtb -O dts "$dtb" > "$pkg/candidate.dts"
diff -u "$pkg/base-r129.dts" "$pkg/candidate.dts" > "$pkg/dtb.diff" || test "$?" = 1
sha256sum "$dtb"
