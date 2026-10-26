#!/usr/bin/env bash
# R164 DT: R161 DT with the CPU interconnect paths removed (no ICC provider in this kernel), so
# qcom-cpufreq-hw (EPSS) can probe instead of deferring on "Failed to find icc paths". This also
# provides the CPU cooling devices used by the DT thermal zones (TSENS loaded as a module).
set -euo pipefail
base=/mnt/d/TB371FC-builds/r161-tfa/board.dtb
pkg=/mnt/d/TB371FC-builds/r164-thermal; mkdir -p "$pkg"
test "$(sha256sum "$base" | cut -d' ' -f1)" = 3ddc9d5856c9cd559752a3753190922fef0bafe3fc27694f57b0e16cf710c221
cp "$base" "$pkg/board.dtb"
cpus=$(fdtget -l "$pkg/board.dtb" /cpus | grep "^cpu@"); echo $cpus; test "$(echo $cpus | wc -w)" = 8
for c in $cpus; do fdtget -p "$pkg/board.dtb" /cpus/$c | grep -qx interconnects; fdtput -d "$pkg/board.dtb" /cpus/$c interconnects; done
dtc -q -s -I dtb -O dts "$base" > "$pkg/baseline-r161.dts"
dtc -q -s -I dtb -O dts "$pkg/board.dtb" > "$pkg/candidate.dts"
diff -u "$pkg/baseline-r161.dts" "$pkg/candidate.dts" > "$pkg/dtb.diff" || test "$?" = 1
grep -c '^-.*interconnects' "$pkg/dtb.diff"; grep -c '^[-+][^-+]' "$pkg/dtb.diff"
sha256sum "$pkg/board.dtb"
