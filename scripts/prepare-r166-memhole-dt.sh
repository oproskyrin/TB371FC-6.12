#!/usr/bin/env bash
# R166 DT: R165 DT + no-map reserved-memory over 0x1d0000000..0x1d3ffffff. Under kexec from the
# 4.19 console this RAM (a 52 MiB band of 1 MiB compound allocations in 4.19) hangs the CPU on any
# access from 6.12 (read-only scan stopped between 0x1d0c00000 and 0x1d0d00000 on two boots).
set -euo pipefail
base=/mnt/d/TB371FC-builds/r165-cpufreq/board.dtb
pkg=/mnt/d/TB371FC-builds/r166-memhole; mkdir -p "$pkg"
test "$(sha256sum "$base" | cut -d' ' -f1)" = a7058d8e27fa0d7dd236811b66f41647e9a590d580b3ae88056f428f5b5c2514
dtc -q -s -I dtb -O dts "$base" > "$pkg/baseline-r165.dts"
cat "$pkg/baseline-r165.dts" - > "$pkg/candidate-src.dts" <<'DTS'

&{/reserved-memory} {
	tb371fc_kexec_hole0: memory@1d0000000 {
		reg = <0x1 0xd0000000 0x0 0x4000000>;
		no-map;
	};
};
DTS
dtc -q -I dts -O dtb -o "$pkg/board.dtb" "$pkg/candidate-src.dts"
dtc -q -s -I dtb -O dts "$pkg/board.dtb" > "$pkg/candidate.dts"
diff -u "$pkg/baseline-r165.dts" "$pkg/candidate.dts" > "$pkg/dtb.diff" || test "$?" = 1
cat "$pkg/dtb.diff"
a=/mnt/d/TB371FC-builds/r164-autoboot
(cd "$a"; grep -E " (Image|initramfs.cpio.gz)$" SHA256SUMS | sha256sum -c -)
cp "$a/Image" "$a/initramfs.cpio.gz" "$pkg/"
cd "$pkg"; sha256sum Image board.dtb initramfs.cpio.gz > SHA256SUMS
tar -czf r166-payload.tar.gz Image board.dtb initramfs.cpio.gz; sha256sum r166-payload.tar.gz >> SHA256SUMS; cat SHA256SUMS
