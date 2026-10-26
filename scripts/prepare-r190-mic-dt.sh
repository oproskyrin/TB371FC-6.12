#!/usr/bin/env bash
# R190 DT (test): R185 DT + microphones. Stock vendor mixer_paths_qrd.xml: two analog mics on the
# WCD938x (ADC1 <- AMIC1, ADC4 INP5 <- AMIC5) over the TX SoundWire to the TX macro, TX_CDC_DMA_TX_3.
# Same codec topology as kona MTP: nodes follow upstream sm8250-mtp.dts; reset GPIO32 (stock
# msm_cdc_pinctrl@32), supplies S4A 1.8 V / BOB, mic bias AMIC1<-MIC BIAS1, AMIC5<-MIC BIAS4.
set -euo pipefail
base=/mnt/d/TB371FC-builds/r185-autoboot/board.dtb; pkg=/mnt/d/TB371FC-builds/r190-mic;  # R191b: fixed stand-in supplies
 mkdir -p "$pkg"
test "$(sha256sum "$base" | cut -d' ' -f1)" = a02916b971a9930c57da05485ef8e1ea63e0e669832286d11e17d8b0603cb79d
dtc -q -s -I dtb -O dts "$base" > "$pkg/base.dts"
plat=$(awk '/speaker-dai-link \{/{s=1} s && /platform \{/{f=1} s && f && /sound-dai/{print; exit}' "$pkg/base.dts" | grep -o '<.*>')
[ -n "$plat" ]
asm=$(awk '/mm1-dai-link \{/{s=1} s && /sound-dai/{print; exit}' "$pkg/base.dts" | grep -o '<0x[0-9a-f]*')
[ -n "$asm" ]; echo "q6asm dai: $asm"
echo "q6routing platform: $plat"
cat "$pkg/base.dts" - > "$pkg/src.dts" <<DTS

/ {
	/* S4A 1.8 V and BOB are kept on by the firmware; the RPMh regulator driver is not loaded on
	   this system (R140), so the codec gets always-on fixed stand-ins instead of rpmh handles. */
	tb371fc_s4a_1p8: regulator-tb371fc-s4a-1p8 {
		compatible = "regulator-fixed";
		regulator-name = "tb371fc_s4a_1p8";
		regulator-min-microvolt = <1800000>;
		regulator-max-microvolt = <1800000>;
		regulator-always-on;
		regulator-boot-on;
	};

	tb371fc_bob: regulator-tb371fc-bob {
		compatible = "regulator-fixed";
		regulator-name = "tb371fc_bob";
		regulator-min-microvolt = <3296000>;
		regulator-max-microvolt = <3296000>;
		regulator-always-on;
		regulator-boot-on;
	};

	wcd938x: audio-codec {
		compatible = "qcom,wcd9380-codec";
		reset-gpios = <&{/soc@0/pinctrl@f100000} 32 1>;
		vdd-buck-supply = <&tb371fc_s4a_1p8>;
		vdd-rxtx-supply = <&tb371fc_s4a_1p8>;
		vdd-io-supply = <&tb371fc_s4a_1p8>;
		vdd-mic-bias-supply = <&tb371fc_bob>;
		qcom,micbias1-microvolt = <1800000>;
		qcom,micbias2-microvolt = <1800000>;
		qcom,micbias3-microvolt = <1800000>;
		qcom,micbias4-microvolt = <1800000>;
		qcom,mbhc-buttons-vthreshold-microvolt = <75000 150000 237000 500000 500000 500000 500000 500000>;
		qcom,mbhc-headset-vthreshold-microvolt = <1700000>;
		qcom,mbhc-headphone-vthreshold-microvolt = <50000>;
		qcom,rx-device = <&wcd_rx>;
		qcom,tx-device = <&wcd_tx>;
		#sound-dai-cells = <1>;
	};
};

&{/soc@0/rxmacro@3200000} { status = "okay"; };
&{/soc@0/txmacro@3220000} { status = "okay"; };

&{/soc@0/soundwire@3210000} {
	status = "okay";
	wcd_rx: wcd9380-rx@0,4 {
		compatible = "sdw20217010d00";
		reg = <0 4>;
		qcom,rx-port-mapping = <1 2 3 4 5>;
	};
};

&{/soc@0/soundwire@3230000} {
	status = "okay";
	wcd_tx: wcd9380-tx@0,3 {
		compatible = "sdw20217010d00";
		reg = <0 3>;
		qcom,tx-port-mapping = <2 3 4 5>;
	};
};

&{/soc@0/remoteproc@17300000/glink-edge/apr/service@4/dais} {
	dai@120 { reg = <120>; };	/* TX_CODEC_DMA_TX_3 */
};

&{/sound} {
	audio-routing =
		"AMIC1", "MIC BIAS1",
		"AMIC5", "MIC BIAS4",
		"TX SWR_ADC0", "ADC1_OUTPUT",
		"TX SWR_ADC1", "ADC2_OUTPUT",
		"TX SWR_ADC2", "ADC3_OUTPUT",
		"TX SWR_ADC3", "ADC4_OUTPUT";

	/* separate frontend for capture: one q6routing session keeps one port (MultiMedia1 = speakers) */
	mm2-dai-link {
		link-name = "MultiMedia2";
		cpu { sound-dai = $asm 1>; };
	};

	wcd-capture-dai-link {
		link-name = "WCD Capture";
		cpu { sound-dai = <&{/soc@0/remoteproc@17300000/glink-edge/apr/service@4/dais} 120>; };
		codec { sound-dai = <&wcd938x 1>, <&{/soc@0/soundwire@3230000} 0>, <&{/soc@0/txmacro@3220000} 0>; };
		platform { sound-dai = $plat; };
	};
};
DTS
dtc -q -I dts -O dtb -o "$pkg/board.dtb" "$pkg/src.dts"
d=$pkg/board.dtb; tlmm=/soc@0/pinctrl@f100000
old=$(fdtget -t u "$d" $tlmm gpio-reserved-ranges); new=$(echo "$old" | sed 's/ 22 14 / 22 10 33 3 /')
[ "$old" != "$new" ]; fdtput -t u "$d" $tlmm gpio-reserved-ranges $new
fdtget -t u "$d" $tlmm gpio-reserved-ranges
dtc -q -s -I dtb -O dts "$d" > "$pkg/r190.dts"; diff -u "$pkg/base.dts" "$pkg/r190.dts" > "$pkg/dtb.diff" || true
grep -c '^[+-]' "$pkg/dtb.diff"; sha256sum "$d"
