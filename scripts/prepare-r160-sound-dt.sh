#!/usr/bin/env bash
# R160 DT: R158 (=R153) DT + PRI_TDM_RX_0 AFE port with Lenovo stock TDM parameters
# (msm-audio-lpass.dtsi: sync-mode 1, sync-src 1 internal, data-out 0, invert-sync 1,
# data-delay 1, data-align 0) and a sound card whose speaker link ends in a placeholder
# codec (linux,spdif-dit). TFA9894 nodes stay disabled; no pinctrl for TDM pins.
set -euo pipefail
base=/mnt/d/TB371FC-builds/r158-nosleep/board.dtb
pkg=/mnt/d/TB371FC-builds/r160-sound
mkdir -p "$pkg"
test "$(sha256sum "$base" | cut -d' ' -f1)" = e336fb1f3b1f200264b09db4eea6c115ae2c1b07efb647f0fab85aac29ee9b21
apr=/soc@0/remoteproc@17300000/glink-edge/apr
dtc -q -s -I dtb -O dts "$base" > "$pkg/baseline-r158.dts"
test -z "$(fdtget -p "$base" /sound | grep -v '^name$' || true)"
cat "$pkg/baseline-r158.dts" - > "$pkg/candidate-src.dts" <<DTS

&{$apr/service@4/dais} {
	dai@24 {
		reg = <24>;	/* PRIMARY_TDM_RX_0 */
		qcom,tdm-sync-mode = <1>;
		qcom,tdm-sync-src = <1>;
		qcom,tdm-data-out = <0>;
		qcom,tdm-invert-sync = <1>;
		qcom,tdm-data-delay = <1>;
		qcom,tdm-data-align = <0>;
	};
};

&{/} {
	speaker-placeholder-codec {
		compatible = "linux,spdif-dit";
		#sound-dai-cells = <0>;
	};
};

&{/sound} {
	compatible = "lenovo,tb371fc-sndcard";
	model = "Lenovo-TB371FC";

	mm1-dai-link {
		link-name = "MultiMedia1";
		cpu { sound-dai = <&{$apr/service@7/dais} 0>; };
	};

	speaker-dai-link {
		link-name = "Speaker Playback";
		cpu { sound-dai = <&{$apr/service@4/dais} 24>; };
		platform { sound-dai = <&{$apr/service@8/routing}>; };
		codec { sound-dai = <&{/speaker-placeholder-codec}>; };
	};
};
DTS
dtc -q -I dts -O dtb -o "$pkg/board.dtb" "$pkg/candidate-src.dts"
dtc -q -s -I dtb -O dts "$pkg/board.dtb" > "$pkg/candidate.dts"
diff -u "$pkg/baseline-r158.dts" "$pkg/candidate.dts" > "$pkg/dtb.diff" || test "$?" = 1
# phandles must be unique
grep -o "phandle = <0x[0-9a-f]*>" "$pkg/candidate.dts" | sort | uniq -d | (! grep .)
cat "$pkg/dtb.diff"
sha256sum "$pkg/board.dtb"
