#!/usr/bin/env bash
# R141: exact R139 Image/initramfs (gated r139_panel module) + DT changes:
#  1) R140 fix: framebuffer holds RPMh MMCX at NOM (visible splash until msm takes over)
#  2) Adreno GPU and GMU disabled, so msm binds DPU+DSI only (msm_drv.c
#     add_gpu_components() skips an unavailable GPU node).
set -euo pipefail
base=/mnt/d/TB371FC-builds/r139-panel-gates
pkg=/mnt/d/TB371FC-builds/r141-dpu-only
fb=/chosen/framebuffer@9c000000
gpu=/soc@0/gpu@3d00000
gmu=/soc@0/gmu@3d6a000
test ! -e "$pkg"
(cd "$base"; sha256sum -c SHA256SUMS)
test "$(sha256sum "$base/board.dtb" | cut -d' ' -f1)" = 1f862a11b08408aed3f56a2542562417475d5a6b6af7120466b91d352ecab5ef
mkdir "$pkg"
cp "$base/Image" "$base/initramfs.cpio.gz" "$base/board.dtb" "$base/r139_panel.ko" "$base/r139_panel.c" "$pkg/"
d="$pkg/board.dtb"
test "$(fdtget -t s "$d" /soc@0/rsc@18200000/power-controller compatible)" = qcom,sm8250-rpmhpd
test "$(fdtget -t x "$d" /soc@0/rsc@18200000/power-controller phandle)" = 34
test "$(fdtget -t x "$d" /soc@0/rsc@18200000/power-controller/opp-table/opp6 phandle)" = 6b
test "$(fdtget -t x "$d" /soc@0/rsc@18200000/power-controller/opp-table/opp6 opp-level)" = 100
test "$(fdtget -t x "$d" /soc@0/display-subsystem@ae00000/display-controller@ae01000 power-domains)" = "34 6"
test "$(fdtget -t s "$d" "$fb" compatible)" = simple-framebuffer
test "$(fdtget -t s "$d" "$gpu" status)" = okay
test "$(fdtget -t s "$d" "$gmu" status)" = okay
! fdtget "$d" "$fb" power-domains 2>/dev/null
fdtput -t x "$d" "$fb" power-domains 34 6
fdtput -t x "$d" "$fb" required-opps 6b
fdtput -t s "$d" "$gpu" status disabled
fdtput -t s "$d" "$gmu" status disabled
dtc -q -s -I dtb -O dts "$base/board.dtb" > "$pkg/baseline-r139.dts"
dtc -q -s -I dtb -O dts "$d" > "$pkg/candidate.dts"
diff -u "$pkg/baseline-r139.dts" "$pkg/candidate.dts" > "$pkg/dtb.diff" || test "$?" = 1
# Roundtrip: reverting the 4 property edits must give the exact R139 DT.
cp "$d" "$pkg/rt.dtb"
fdtput -d "$pkg/rt.dtb" "$fb" power-domains
fdtput -d "$pkg/rt.dtb" "$fb" required-opps
fdtput -t s "$pkg/rt.dtb" "$gpu" status okay
fdtput -t s "$pkg/rt.dtb" "$gmu" status okay
dtc -q -s -I dtb -O dts "$pkg/rt.dtb" > "$pkg/rt.dts"
cmp "$pkg/baseline-r139.dts" "$pkg/rt.dts"
rm "$pkg/rt.dtb" "$pkg/rt.dts"
cmp "$pkg/Image" "$base/Image"
cmp "$pkg/initramfs.cpio.gz" "$base/initramfs.cpio.gz"
cd "$pkg"
sha256sum Image board.dtb initramfs.cpio.gz r139_panel.c r139_panel.ko > SHA256SUMS
tar -czf r141-payload.tar.gz Image board.dtb initramfs.cpio.gz
sha256sum r141-payload.tar.gz >> SHA256SUMS
cat SHA256SUMS
cat dtb.diff
