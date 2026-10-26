#!/usr/bin/env bash
# R171 DT: R170 DT + UART6 (serial@998000, QCA6390 Bluetooth) usable: TLMM gpio16..19 freed and
# the UART's interconnects removed (no ICC provider; it would defer forever).
set -euo pipefail
base=/mnt/d/TB371FC-builds/r170-backlight/board.dtb
pkg=/mnt/d/TB371FC-builds/r171-bt; mkdir -p "$pkg"
test "$(sha256sum "$base" | cut -d' ' -f1)" = a99cb12414292f886bd30f2ab31652ed8d92996d2224cfbd4d36dc43e2888655
tlmm=/soc@0/pinctrl@f100000; u=/soc@0/geniqup@9c0000/serial@998000
test "$(fdtget -t u "$base" $tlmm gpio-reserved-ranges)" = "0 12 14 6 22 14 38 2 46 10 57 3 62 6 69 6 76 3 83 25 109 1 111 3 119 19 142 39"
ph=$(fdtget -t x "$base" $u pinctrl-0)
dtc -q -s -I dtb -O dts "$base" > "$pkg/baseline-r170.dts"
grep -B12 "phandle = <0x$ph>;" "$pkg/baseline-r170.dts" | grep -E "state|pins" | tr -s '\t' ' '
cat "$pkg/baseline-r170.dts" - > "$pkg/candidate-src.dts" <<DTS

&{$tlmm} {
	gpio-reserved-ranges = <0 12>, <14 2>, <22 14>, <38 2>, <46 10>, <57 3>, <62 6>, <69 6>,
			       <76 3>, <83 25>, <109 1>, <111 3>, <119 19>, <142 39>;
};
&{$u} {
	/delete-property/ interconnects;
	/delete-property/ interconnect-names;
};
/* qcom_geni_serial needs a serialN alias for its line number ("Invalid line -19" without it) */
&{/aliases} {
	serial0 = "/soc@0/geniqup@9c0000/serial@988000";
	serial1 = "$u";
};
DTS
dtc -q -I dts -O dtb -o "$pkg/board.dtb" "$pkg/candidate-src.dts"
dtc -q -s -I dtb -O dts "$pkg/board.dtb" > "$pkg/candidate.dts"
diff -u "$pkg/baseline-r170.dts" "$pkg/candidate.dts" > "$pkg/dtb.diff" || test "$?" = 1
cat "$pkg/dtb.diff"; sha256sum "$pkg/board.dtb"
a=/mnt/d/TB371FC-builds/r170-autoboot
(cd "$a"; grep -E " (Image|initramfs.cpio.gz)$" SHA256SUMS | sha256sum -c -)
cp "$a/Image" "$a/initramfs.cpio.gz" "$pkg/"
cd "$pkg"; sha256sum Image board.dtb initramfs.cpio.gz > SHA256SUMS
tar -czf r171t-payload.tar.gz Image board.dtb initramfs.cpio.gz; sha256sum r171t-payload.tar.gz >> SHA256SUMS; cat SHA256SUMS
