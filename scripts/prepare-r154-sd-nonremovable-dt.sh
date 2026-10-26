#!/usr/bin/env bash
# R154 DT: R153 DT with the microSD controller switched from broken-cd (1 s card-detect
# polling) to non-removable. Under a long write (16 GB exFAT zero-fill, R154 attempt 1)
# the polling declared "mmc0: card 59b4 removed", dropping the root filesystem.
# The microSD holds the root image and is never hot-removed.
set -euo pipefail
base=/mnt/d/TB371FC-builds/r153-keyboard/board.dtb
pkg=/mnt/d/TB371FC-builds/r154-persist
d="$pkg/board.dtb"
mmc=/soc@0/mmc@8804000
mkdir -p "$pkg"; test ! -e "$d"
test "$(sha256sum "$base" | cut -d' ' -f1)" = e336fb1f3b1f200264b09db4eea6c115ae2c1b07efb647f0fab85aac29ee9b21
cp "$base" "$d"
fdtget "$d" $mmc broken-cd >/dev/null 2>&1 || fdtget -p "$d" $mmc | grep -qx broken-cd
! fdtget -p "$d" $mmc | grep -qx non-removable
fdtput -d "$d" $mmc broken-cd
fdtput "$d" $mmc non-removable
dtc -q -s -I dtb -O dts "$base" > "$pkg/baseline-r153.dts"
dtc -q -s -I dtb -O dts "$d" > "$pkg/candidate.dts"
diff -u "$pkg/baseline-r153.dts" "$pkg/candidate.dts" > "$pkg/dtb.diff" || test "$?" = 1
cat "$pkg/dtb.diff"
sha256sum "$d"
