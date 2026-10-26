#!/usr/bin/env bash
set -euo pipefail
base=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r118-pinctrl/board.dtb
pkg=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r125-no-gpio75-hog
node=/soc/pinctrl@f100000/sd-redriver-hog
printf '%s  %s\n' 311a8197a58823d7b917a1dc4a050939f074f5c9fb149cc7e11464772f6bf819 "$base" | sha256sum -c -
test ! -e "$pkg"
mkdir "$pkg"
cp "$base" "$pkg/board.dtb"
fdtput -t s "$pkg/board.dtb" "$node" status disabled
test "$(fdtget -t s "$pkg/board.dtb" "$node" status)" = disabled
dtc -q -I dtb -O dts "$base" > "$pkg/baseline.dts"
dtc -q -I dtb -O dts "$pkg/board.dtb" > "$pkg/candidate.dts"
diff -u "$pkg/baseline.dts" "$pkg/candidate.dts" > "$pkg/dtb.diff" || test "$?" = 1
cp "$pkg/board.dtb" "$pkg/roundtrip.dtb"
fdtput -d "$pkg/roundtrip.dtb" "$node" status
dtc -q -I dtb -O dts "$pkg/roundtrip.dtb" > "$pkg/roundtrip.dts"
cmp "$pkg/baseline.dts" "$pkg/roundtrip.dts"
(cd "$pkg"; sha256sum board.dtb > SHA256SUMS; cat SHA256SUMS; cat dtb.diff)
