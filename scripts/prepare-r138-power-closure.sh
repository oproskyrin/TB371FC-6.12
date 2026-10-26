#!/usr/bin/env bash
set -euo pipefail
project="$(cd "$(dirname "$0")/.." && pwd)"
base=/mnt/d/TB371FC-builds/r137-native-prereqs
pkg=/mnt/d/TB371FC-builds/r138-power-closure
test ! -e "$pkg"
mkdir "$pkg"
(cd "$base"; sha256sum -c SHA256SUMS)
cp "$base/Image" "$base/board.dtb" "$base/initramfs.cpio.gz" "$pkg/"
for node in /soc/rsc@18200000/regulators-0/smps5 /soc/rsc@18200000/regulators-0/smps6 /soc/rsc@18200000/regulators-1/smps8; do
    test "$(fdtget -t s "$pkg/board.dtb" "$node" status)" = disabled
    fdtput -t s "$pkg/board.dtb" "$node" status okay
done
python3 "$project/scripts/audit-r137-display-power.py" "$pkg/board.dtb" --require-closure > "$pkg/power-closure-audit.txt"
dtc -q -s -I dtb -O dts "$base/board.dtb" > "$pkg/baseline-r137.dts"
dtc -q -s -I dtb -O dts "$pkg/board.dtb" > "$pkg/candidate.dts"
diff -u "$pkg/baseline-r137.dts" "$pkg/candidate.dts" > "$pkg/dtb.diff" || test "$?" = 1
# Roundtrip proves these3 properties are the ONLY DT changes.
cp "$pkg/board.dtb" "$pkg/roundtrip.dtb"
for node in /soc/rsc@18200000/regulators-0/smps5 /soc/rsc@18200000/regulators-0/smps6 /soc/rsc@18200000/regulators-1/smps8; do
    fdtput -t s "$pkg/roundtrip.dtb" "$node" status disabled
done
dtc -q -s -I dtb -O dts "$pkg/roundtrip.dtb" > "$pkg/roundtrip.dts"
cmp "$pkg/baseline-r137.dts" "$pkg/roundtrip.dts"
cmp "$pkg/Image" "$base/Image"
cmp "$pkg/initramfs.cpio.gz" "$base/initramfs.cpio.gz"
(cd "$pkg"; sha256sum Image board.dtb initramfs.cpio.gz > SHA256SUMS; tar -czf r138-power-closure-payload.tar.gz Image board.dtb initramfs.cpio.gz; cat SHA256SUMS)
