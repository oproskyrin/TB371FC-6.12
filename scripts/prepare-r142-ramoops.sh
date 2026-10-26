#!/usr/bin/env bash
# R142: exact R141 payload + a ramoops region so the console survives a hang.
# Region 0x9e380000+0x80000 lies inside 4.19's reserved dfps_data_region
# (0x9e300000+0x100000), so the first-stage 4.19 should not reuse it; the low
# half is left alone in case the bootloader writes dfps data there.
set -euo pipefail
base=/mnt/d/TB371FC-builds/r141-dpu-only
pkg=/mnt/d/TB371FC-builds/r142-ramoops
test ! -e "$pkg"
(cd "$base"; head -5 SHA256SUMS | sha256sum -c -)
mkdir "$pkg"
cp "$base/Image" "$base/initramfs.cpio.gz" "$base/board.dtb" "$base/r139_panel.ko" "$base/r139_panel.c" "$pkg/"
d="$pkg/board.dtb"
rm=/reserved-memory
test "$(fdtget -t x "$d" $rm '#address-cells')" = 2
test "$(fdtget -t x "$d" $rm '#size-cells')" = 2
# No existing node may overlap 0x9e380000..0x9e3fffff.
dtc -q -I dtb -O dts "$d" > "$pkg/pre.dts"
! grep -q -E "memory@9e3|ramoops" "$pkg/pre.dts"
n=$rm/ramoops@9e380000
fdtput -c "$d" $n
fdtput -t s "$d" $n compatible ramoops
fdtput -t x "$d" $n reg 0 0x9e380000 0 0x80000
fdtput -t x "$d" $n console-size 0x40000
fdtput -t x "$d" $n record-size 0x20000
fdtput -t x "$d" $n pmsg-size 0
fdtput -t x "$d" $n ecc-size 0
fdtput "$d" $n no-map
dtc -q -s -I dtb -O dts "$base/board.dtb" > "$pkg/baseline-r141.dts"
dtc -q -s -I dtb -O dts "$d" > "$pkg/candidate.dts"
diff -u "$pkg/baseline-r141.dts" "$pkg/candidate.dts" > "$pkg/dtb.diff" || test "$?" = 1
cp "$d" "$pkg/rt.dtb"; fdtput -r "$pkg/rt.dtb" $n
dtc -q -s -I dtb -O dts "$pkg/rt.dtb" > "$pkg/rt.dts"; cmp "$pkg/baseline-r141.dts" "$pkg/rt.dts"
rm "$pkg/rt.dtb" "$pkg/rt.dts" "$pkg/pre.dts"
cd "$pkg"
sha256sum Image board.dtb initramfs.cpio.gz r139_panel.c r139_panel.ko > SHA256SUMS
tar -czf r142-payload.tar.gz Image board.dtb initramfs.cpio.gz
sha256sum r142-payload.tar.gz >> SHA256SUMS
cat SHA256SUMS dtb.diff
