#!/usr/bin/env bash
# R168 DT: R166 DT (kexec RAM hole reserved) with the microSD controller switched from broken-cd
# (1 s card-detect polling) to non-removable. During a write the polling CMD13 times out and the
# core declares "mmc0: card 59b4 removed", dropping the root filesystem (R154 and R166 tests).
set -euo pipefail
base=/mnt/d/TB371FC-builds/r166-memhole/board.dtb
pkg=/mnt/d/TB371FC-builds/r168-sdfix; mkdir -p "$pkg"
test "$(sha256sum "$base" | cut -d' ' -f1)" = d427da0e76737f1187614e6409095a42f0c535008016862c4d9c89934e8ad145
mmc=/soc@0/mmc@8804000
cp "$base" "$pkg/board.dtb"
fdtget -p "$pkg/board.dtb" $mmc | grep -qx broken-cd
fdtput -d "$pkg/board.dtb" $mmc broken-cd
fdtput "$pkg/board.dtb" $mmc non-removable
dtc -q -s -I dtb -O dts "$base" > "$pkg/baseline-r166.dts"
dtc -q -s -I dtb -O dts "$pkg/board.dtb" > "$pkg/candidate.dts"
diff -u "$pkg/baseline-r166.dts" "$pkg/candidate.dts" > "$pkg/dtb.diff" || test "$?" = 1
cat "$pkg/dtb.diff"; sha256sum "$pkg/board.dtb"
