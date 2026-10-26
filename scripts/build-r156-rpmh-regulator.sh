#!/usr/bin/env bash
# R156: build qcom-rpmh-regulator as an external module for the R130/R140 kernel
# (REGULATOR_QCOM_RPMH is not set there) and the R156 DT that lets it drive only the
# microSD rails PM8150L LDO9 (card VDD) and LDO6 (I/O) in HPM at 2.96 V.
# Hypothesis: without a load/HPM vote the card rail stays in LPM (~10 mA class) after
# kexec and long writes brown the card out (R154/R155 hangs).
set -euo pipefail
src=/root/tb371fc/linux-6.12-donor-r118
out=/root/tb371fc/build-6.12-r151-wifi          # copy of the r130 output (R151)
mod=/root/tb371fc/r156-rpmh-regulator
pkg=/mnt/d/TB371FC-builds/r156-sd-power
base=/mnt/d/TB371FC-builds/r155-sd-dma/board.dtb
r=/soc@0/rsc@18200000
test ! -e "$pkg"; mkdir -p "$pkg"
rm -rf "$mod"; mkdir -p "$mod"
cp "$src/drivers/regulator/qcom-rpmh-regulator.c" "$mod/"
printf 'obj-m += qcom-rpmh-regulator.o\n' > "$mod/Kbuild"
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 -j8 M="$mod" modules > "$pkg/build.log" 2>&1 || { tail -20 "$pkg/build.log"; exit 1; }
cp "$mod/qcom-rpmh-regulator.ko" "$pkg/"
test "$(modinfo -F vermagic "$pkg/qcom-rpmh-regulator.ko")" = "$(modinfo -F vermagic /mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r130-usb2-late/dwc3-qcom.ko)"

d="$pkg/board.dtb"
test "$(sha256sum "$base" | cut -d' ' -f1)" = cd060078142b95b360b0fc02e3d9d4c337854bf7afcc253838c38cc20fdb980d
cp "$base" "$d"
test "$(fdtget -t s "$d" $r/regulators-1 qcom,pmic-id)" = c
test "$(fdtget -t s "$d" $r/regulators-1/ldo9 regulator-name)" = vreg_l9c_2p7
test "$(fdtget -t s "$d" $r/regulators-1/ldo6 regulator-name)" = vreg_l6c_2p9
fdtput -t s "$d" $r/regulators-0 status disabled
fdtput -t s "$d" $r/regulators-2 status disabled
for p in $(fdtget -p "$d" $r/regulators-1 | grep -- '-supply$'); do fdtput -d "$d" $r/regulators-1 "$p"; done
for c in $(fdtget -l "$d" $r/regulators-1); do
    case "$c" in ldo6|ldo9) ;; *) fdtput -r "$d" $r/regulators-1/$c ;; esac
done
for l in ldo6 ldo9; do
    n=$r/regulators-1/$l
    fdtput -t u "$d" $n regulator-min-microvolt 2960000
    fdtput -t u "$d" $n regulator-max-microvolt 2960000
    fdtput "$d" $n regulator-always-on
    fdtput "$d" $n regulator-boot-on
done
test "$(fdtget -l "$d" $r/regulators-1 | tr '\n' ' ')" = "ldo6 ldo9 "
dtc -q -s -I dtb -O dts "$base" > "$pkg/baseline-r155.dts"
dtc -q -s -I dtb -O dts "$d" > "$pkg/candidate.dts"
diff -u "$pkg/baseline-r155.dts" "$pkg/candidate.dts" > "$pkg/dtb.diff" || test "$?" = 1
grep -c '^[-+]' "$pkg/dtb.diff"
grep -E '^\+' "$pkg/dtb.diff" | head -30
sha256sum "$d" "$pkg/qcom-rpmh-regulator.ko"
