#!/usr/bin/env bash
# R151 DT: R148 (touch) DT + QCA6390 Wi-Fi on PCIe0, following qrb5165-rb5.dts:
#  - pcie@1c00000 and its QMP PHY phy@1c06000: status okay (PHY rails inherited -> dummy)
#  - /qca6390-pmu: external *-supply removed (no RPMh regulator driver in this kernel;
#    the SMPS rails stay on from the boot chain), WLAN_EN gpio20 / BT_EN gpio21 kept
#  - new pcie@0/wifi@0 "pci17cb,1101" powered from the PMU LDOs (pci-pwrctl-pwrseq)
#  - TLMM: additionally free gpio20, 21 (WLAN/BT enable) and 79, 80, 81 (PERST/CLKREQ/WAKE)
set -euo pipefail
base=/mnt/d/TB371FC-builds/r148-touch/board.dtb
pkg=/mnt/d/TB371FC-builds/r151-wifi
d="$pkg/board.dtb"
pcie=/soc@0/pcie@1c00000
phy=/soc@0/phy@1c06000
pmu=/qca6390-pmu
tlmm=/soc@0/pinctrl@f100000
mkdir -p "$pkg"; test ! -e "$d"
test "$(sha256sum "$base" | cut -d' ' -f1)" = b1dd3d85e6b67905aab46d33177461c100a7347399cdaad7cb63dd317ca66a0f
cp "$base" "$d"
test "$(fdtget -t s "$d" $pcie status)" = disabled
test "$(fdtget -t s "$d" $phy status)" = disabled
test "$(fdtget -t s "$d" $pcie compatible)" = qcom,pcie-sm8250
test "$(fdtget -t s "$d" $phy compatible)" = qcom,sm8250-qmp-gen3x1-pcie-phy
test "$(fdtget -t s "$d" $pmu compatible)" = qcom,qca6390-pmu
test "$(fdtget -t x "$d" $pmu wlan-enable-gpios)" = "3b 14 0"
test "$(fdtget -t u "$d" $tlmm gpio-reserved-ranges)" = "0 40 44 12 57 11 69 6 76 6 83 98"
! fdtget "$d" $pcie/pcie@0/wifi@0 compatible 2>/dev/null
fdtput -t s "$d" $pcie status okay
fdtput -t s "$d" $phy status okay
for s in vddaon vddpmu vddrfa0p95 vddrfa1p3 vddrfa1p9 vddpcie1p3 vddpcie1p9 vddio; do
    fdtput -d "$d" $pmu "$s-supply"
done
# phandles of the PMU LDOs (add the ones the base DT does not reference yet)
next=$(( $(dtc -q -I dtb -O dts "$d" | grep -o 'phandle = <0x[0-9a-f]*>' | grep -o '0x[0-9a-f]*' | sort -u | while read h; do printf '%d\n' "$h"; done | sort -n | tail -1) + 1 ))
for l in ldo0 ldo1 ldo2 ldo3 ldo5 ldo6 ldo7 ldo8 ldo9; do
    if ! fdtget -t x "$d" $pmu/regulators/$l phandle >/dev/null 2>&1; then
        fdtput -t x "$d" $pmu/regulators/$l phandle "$(printf %x $next)"
        next=$((next+1))
    fi
done
ph() { fdtget -t x "$d" $pmu/regulators/$1 phandle; }
declare -A sup=( [vddrfacmn]=ldo0 [vddaon]=ldo1 [vddwlcx]=ldo2 [vddwlmx]=ldo3 [vddrfa0p8]=ldo5 [vddrfa1p2]=ldo6 [vddrfa1p7]=ldo7 [vddpcie0p9]=ldo8 [vddpcie1p8]=ldo9 )
w=$pcie/pcie@0/wifi@0
fdtput -c "$d" $w
fdtput -t s "$d" $w compatible pci17cb,1101
fdtput -t x "$d" $w reg 10000 0 0 0 0
for s in vddrfacmn vddaon vddwlcx vddwlmx vddrfa0p8 vddrfa1p2 vddrfa1p7 vddpcie0p9 vddpcie1p8; do
    fdtput -t x "$d" $w "$s-supply" "$(ph ${sup[$s]})"
done
# reserved: 0-19, 22-39, 44-55, 57-67, 69-74, 76-78, 83-180
fdtput -t u "$d" $tlmm gpio-reserved-ranges 0 20 22 18 44 12 57 11 69 6 76 3 83 98
dtc -q -s -I dtb -O dts "$base" > "$pkg/baseline-r148.dts"
dtc -q -s -I dtb -O dts "$d" > "$pkg/candidate.dts"
diff -u "$pkg/baseline-r148.dts" "$pkg/candidate.dts" > "$pkg/dtb.diff" || test "$?" = 1
cat "$pkg/dtb.diff"
sha256sum "$d"
