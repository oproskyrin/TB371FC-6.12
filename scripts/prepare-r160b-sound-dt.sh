#!/usr/bin/env bash
# R160b DT: R160 DT + q6asm frontend dai@0..2 (6.12 q6asm-dai requires dai@N children).
set -euo pipefail
base=/mnt/d/TB371FC-builds/r160-sound/board.dtb
pkg=/mnt/d/TB371FC-builds/r160b-sound
mkdir -p "$pkg"
test "$(sha256sum "$base" | cut -d' ' -f1)" = 65b38f144138bf73de6cd1a2b3239f3e88ada9ce5d5e4e1aa941739945a488c3
apr=/soc@0/remoteproc@17300000/glink-edge/apr
dtc -q -s -I dtb -O dts "$base" > "$pkg/baseline-r160.dts"
cat "$pkg/baseline-r160.dts" - > "$pkg/candidate-src.dts" <<DTS

&{$apr/service@7/dais} {
	#address-cells = <1>;
	#size-cells = <0>;
	dai@0 { reg = <0>; };	/* MultiMedia1 */
	dai@1 { reg = <1>; };	/* MultiMedia2 */
	dai@2 { reg = <2>; };	/* MultiMedia3 */
};
DTS
dtc -q -I dts -O dtb -o "$pkg/board.dtb" "$pkg/candidate-src.dts"
dtc -q -s -I dtb -O dts "$pkg/board.dtb" > "$pkg/candidate.dts"
diff -u "$pkg/baseline-r160.dts" "$pkg/candidate.dts" > "$pkg/dtb.diff" || test "$?" = 1
grep -o "phandle = <0x[0-9a-f]*>" "$pkg/candidate.dts" | sort | uniq -d | (! grep .)
cat "$pkg/dtb.diff"; sha256sum "$pkg/board.dtb"
