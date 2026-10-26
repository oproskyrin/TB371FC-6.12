#!/usr/bin/env bash
# R161 DT: R160b + the existing TFA9894 x4 nodes on i2c15 (i2c@884000, QUP2 SE15, pins 44/45)
# enabled; i2c15 interconnects removed (no ICC provider); USB-C redriver nb7vpq904m@1c on the
# same bus explicitly disabled (USB/SSH must stay untouched). PRI TDM pinmux (138 sck, 139 data0,
# 140 data1, 141 ws; Lenovo kona-pinctrl 8 mA, no pull) on the sound node; speaker link codecs =
# the 4 amps. TLMM: additionally free 44,45 (i2c15), 115-118 (amp resets), 138-141 (TDM).
set -euo pipefail
base=/mnt/d/TB371FC-builds/r160b-sound/board.dtb
pkg=/mnt/d/TB371FC-builds/r161-tfa
mkdir -p "$pkg"
test "$(sha256sum "$base" | cut -d' ' -f1)" = b9aafdb76e567306fb14fffb0b4cc010bb1b8880f864e3dd60ce08d523fd160d
tlmm=/soc@0/pinctrl@f100000
i2c=/soc@0/geniqup@8c0000/i2c@884000
fdtget "$base" $i2c/amplifier@34 compatible
test "$(fdtget -t u "$base" $tlmm gpio-reserved-ranges)" = "0 20 22 14 38 2 44 12 57 11 69 6 76 3 83 25 109 1 111 3 115 66"
dtc -q -s -I dtb -O dts "$base" > "$pkg/baseline-r160b.dts"
cat "$pkg/baseline-r160b.dts" - > "$pkg/candidate-src.dts" <<DTS

&{$tlmm} {
	gpio-reserved-ranges = <0 20>, <22 14>, <38 2>, <46 10>, <57 11>, <69 6>,
			       <76 3>, <83 25>, <109 1>, <111 3>, <119 19>, <142 39>;

	pri_tdm_active: pri-tdm-active-state {
		sck-pins { pins = "gpio138"; function = "mi2s0_sck"; drive-strength = <8>; bias-disable; };
		din-pins { pins = "gpio139"; function = "mi2s0_data0"; drive-strength = <8>; bias-disable; };
		dout-pins { pins = "gpio140"; function = "mi2s0_data1"; drive-strength = <8>; bias-disable; };
		ws-pins { pins = "gpio141"; function = "mi2s0_ws"; drive-strength = <8>; bias-disable; };
	};
};

&{$i2c} {
	/delete-property/ interconnects;
	/delete-property/ interconnect-names;
};
&{$i2c/typec-mux@1c} { status = "disabled"; };
&{$i2c/amplifier@34} { status = "okay"; };
&{$i2c/amplifier@35} { status = "okay"; };
&{$i2c/amplifier@36} { status = "okay"; };
&{$i2c/amplifier@37} { status = "okay"; };

&{/sound} {
	pinctrl-names = "default";
	pinctrl-0 = <&pri_tdm_active>;
};

&{/sound/speaker-dai-link/codec} {
	sound-dai = <&{$i2c/amplifier@34} 0>, <&{$i2c/amplifier@35} 0>,
		    <&{$i2c/amplifier@36} 0>, <&{$i2c/amplifier@37} 0>;
};
DTS
dtc -q -I dts -O dtb -o "$pkg/board.dtb" "$pkg/candidate-src.dts"
dtc -q -s -I dtb -O dts "$pkg/board.dtb" > "$pkg/candidate.dts"
diff -u "$pkg/baseline-r160b.dts" "$pkg/candidate.dts" > "$pkg/dtb.diff" || test "$?" = 1
grep -o "phandle = <0x[0-9a-f]*>" "$pkg/candidate.dts" | sort | uniq -d | (! grep .)
cat "$pkg/dtb.diff"; sha256sum "$pkg/board.dtb"
