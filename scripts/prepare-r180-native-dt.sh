#!/usr/bin/env bash
# R180 DT (native display test): R177 DT (board-dma50p, microSD DMA 50 MHz + pads) with the native
# display path enabled as in R141/R146: DPU "lenovo,tb371fc-dpu" (linewidth 1880), both DSI + PHY
# ("lenovo,tb371fc-dsi-phy-7nm" lane config), Tianma NT36532 panel (reset GPIO 69 opened), DP off,
# GPU/GMU off (isolate DPU like R141). No regulator/interconnect dependencies (rails and bandwidth are
# held from the bootloader splash; there is no ICC provider and rpmh-regulator would reset voltages).
set -euo pipefail
base=/mnt/d/TB371FC-builds/r176-sd-speed/board-dma50p.dtb
pkg=/mnt/d/TB371FC-builds/r180-native; d=$pkg/board.dtb
test "$(sha256sum "$base" | cut -d' ' -f1)" = 635df17d4baed1046c9c21453021227fb1b2bbd8599a8a44a6bf706e231d36f8
cp "$base" "$d"
m=/soc@0/display-subsystem@ae00000; dpu=$m/display-controller@ae01000
dsi0=$m/dsi@ae94000; dsi1=$m/dsi@ae96000; phy0=$m/phy@ae94400; phy1=$m/phy@ae96400; panel=$dsi0/panel@0
tlmm=/soc@0/pinctrl@f100000
fdtput -d "$d" $m interconnects; fdtput -d "$d" $m interconnect-names
fdtput -t s "$d" $dpu compatible lenovo,tb371fc-dpu
fdtput -t s "$d" $m/displayport-controller@ae90000 status disabled
for n in $dsi0 $dsi1; do fdtput -t s "$d" $n status okay; fdtput -d "$d" $n vdda-supply; done
for n in $phy0 $phy1; do fdtput -t s "$d" $n status okay; fdtput -t s "$d" $n compatible lenovo,tb371fc-dsi-phy-7nm; fdtput -d "$d" $n vdds-supply; done
fdtput -t s "$d" $panel compatible lenovo,tb371fc-tianma-nt36532 novatek,nt36523
fdtput -t s "$d" $panel status okay; fdtput -d "$d" $panel vddio-supply
fdtput -t s "$d" /soc@0/gpu@3d00000 status disabled; fdtput -t s "$d" /soc@0/gmu@3d6a000 status disabled
test "$(fdtget -t u "$d" $tlmm gpio-reserved-ranges)" = "0 12 14 2 22 14 38 2 46 10 57 3 62 6 69 6 76 3 83 25 109 1 111 3 119 19 142 39"
fdtput -t u "$d" $tlmm gpio-reserved-ranges 0 12 14 2 22 11 34 2 38 2 46 8 55 1 57 3 62 6 70 5 76 1 83 25 109 1 111 3 119 19 142 39
dtc -q -s -I dtb -O dts "$base" > "$pkg/baseline.dts"; dtc -q -s -I dtb -O dts "$d" > "$pkg/candidate.dts"
diff -u "$pkg/baseline.dts" "$pkg/candidate.dts" > "$pkg/dtb.diff" || true
grep -c "^[-+]" "$pkg/dtb.diff"; sha256sum "$d"
