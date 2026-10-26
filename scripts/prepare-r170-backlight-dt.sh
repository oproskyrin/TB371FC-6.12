#!/usr/bin/env bash
# R170 DT: R166/R167 DT + I2C5 (i2c@994000, gpio12/13) and I2C11 (i2c@a8c000, gpio60/61) enabled
# without interconnects, each with a KTZ8866 backlight controller at 0x11 (one primary). No GPIOs
# are touched (HWEN 54 and bias 77/78 stay as the bootloader left them).
set -euo pipefail
base=/mnt/d/TB371FC-builds/r166-memhole/board.dtb
pkg=/mnt/d/TB371FC-builds/r170-backlight; mkdir -p "$pkg"
test "$(sha256sum "$base" | cut -d' ' -f1)" = d427da0e76737f1187614e6409095a42f0c535008016862c4d9c89934e8ad145
tlmm=/soc@0/pinctrl@f100000; i5=/soc@0/geniqup@9c0000/i2c@994000; i11=/soc@0/geniqup@ac0000/i2c@a8c000
test "$(fdtget -t u "$base" $tlmm gpio-reserved-ranges)" = "0 20 22 14 38 2 46 10 57 11 69 6 76 3 83 25 109 1 111 3 119 19 142 39"
dtc -q -s -I dtb -O dts "$base" > "$pkg/baseline-r166.dts"
cat "$pkg/baseline-r166.dts" - > "$pkg/candidate-src.dts" <<DTS

&{$tlmm} {
	gpio-reserved-ranges = <0 12>, <14 6>, <22 14>, <38 2>, <46 10>, <57 3>, <62 6>, <69 6>,
			       <76 3>, <83 25>, <109 1>, <111 3>, <119 19>, <142 39>;
};
&{$i5} {
	status = "okay";
	clock-frequency = <400000>;
	/delete-property/ interconnects;
	/delete-property/ interconnect-names;
	backlight@11 { compatible = "lenovo,tb371fc-ktz8866"; reg = <0x11>; lenovo,primary-backlight; };
};
&{$i11} {
	status = "okay";
	clock-frequency = <400000>;
	/delete-property/ interconnects;
	/delete-property/ interconnect-names;
	backlight@11 { compatible = "lenovo,tb371fc-ktz8866"; reg = <0x11>; };
};
DTS
dtc -q -I dts -O dtb -o "$pkg/board.dtb" "$pkg/candidate-src.dts"
dtc -q -s -I dtb -O dts "$pkg/board.dtb" > "$pkg/candidate.dts"
diff -u "$pkg/baseline-r166.dts" "$pkg/candidate.dts" > "$pkg/dtb.diff" || test "$?" = 1
cat "$pkg/dtb.diff"; sha256sum "$pkg/board.dtb"
