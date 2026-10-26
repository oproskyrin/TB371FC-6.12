#!/usr/bin/env bash
# R192 DT (test): R191 DT + rear camera (OFILM S5K4H7, see CAMERA_PORT.md and
# sm8250-lenovo-tb371fc-s5k4h7-test.dts): camcc, CAMSS CSIPHY0 4-lane D-PHY, CCI0 bus 0 @0x10,
# reset GPIO93, MCLK0 GPIO94 24 MHz. Sensor rails are the real RPMh LDOs at the stock voltages
# (L13A 2.8 V analog, L3C 1.2 V digital, L5C 1.8 V I/O); the CAMSS PHY rails (L5A/L9A, shared with
# PCIe/USB) get always-on fixed stand-ins so camera power management can never drop them.
# Actuator, EEPROM, flash and the front camera stay off.
set -euo pipefail
base=/mnt/d/TB371FC-builds/r190-mic/board.dtb; pkg=/mnt/d/TB371FC-builds/r192-cam-dt; mkdir -p "$pkg"
test "$(sha256sum "$base" | cut -d' ' -f1)" = 52a5d5775c04f88d3e424b767ad6e0f7e04540aace7df024b732d96e75c84bc6
dtc -q -s -I dtb -O dts "$base" > "$pkg/base.dts"
R=/soc@0/rsc@18200000
cat "$pkg/base.dts" - > "$pkg/src.dts" <<DTS

/ {
	tb371fc_camss_phy: regulator-tb371fc-camss-phy-0p88 {
		compatible = "regulator-fixed";
		regulator-name = "tb371fc_camss_phy_0p88";
		regulator-min-microvolt = <880000>;
		regulator-max-microvolt = <880000>;
		regulator-always-on;
	};

	tb371fc_camss_pll: regulator-tb371fc-camss-pll-1p2 {
		compatible = "regulator-fixed";
		regulator-name = "tb371fc_camss_pll_1p2";
		regulator-min-microvolt = <1200000>;
		regulator-max-microvolt = <1200000>;
		regulator-always-on;
	};
};

&{$R/regulators-0/ldo13} { regulator-min-microvolt = <2800000>; regulator-max-microvolt = <2800000>; };
&{$R/regulators-1/ldo3} { regulator-min-microvolt = <1200000>; regulator-max-microvolt = <1200000>; };
&{$R/regulators-1/ldo5} { regulator-min-microvolt = <1800000>; regulator-max-microvolt = <1800000>; };

&{/soc@0/clock-controller@ad00000} { status = "okay"; };

&{/soc@0/camss@ac6a000} {
	vdda-phy-supply = <&tb371fc_camss_phy>;
	vdda-pll-supply = <&tb371fc_camss_pll>;
	status = "okay";
	ports {
		port@0 {
			camss_csiphy0_ep: endpoint {
				bus-type = <4>;
				clock-lanes = <7>;
				data-lanes = <0 1 2 3>;
				remote-endpoint = <&s5k4h7_ep>;
			};
		};
	};
};

&{/soc@0/cci@ac4f000} { status = "okay"; };

&{/soc@0/cci@ac4f000/i2c-bus@0} {
	s5k4h7: camera@10 {
		compatible = "samsung,s5k4h7";
		reg = <0x10>;
		clocks = <&{/soc@0/clock-controller@ad00000} 73>;
		assigned-clocks = <&{/soc@0/clock-controller@ad00000} 73>;
		assigned-clock-rates = <24000000>;
		pinctrl-names = "default";
		pinctrl-0 = <&cam0_default>;
		reset-gpios = <&{/soc@0/pinctrl@f100000} 93 1>;
		vdda-supply = <&{$R/regulators-0/ldo13}>;
		vddd-supply = <&{$R/regulators-1/ldo3}>;
		vddio-supply = <&{$R/regulators-1/ldo5}>;
		rotation = <90>;
		port {
			s5k4h7_ep: endpoint {
				clock-lanes = <0>;
				data-lanes = <1 2 3 4>;
				link-frequencies = /bits/ 64 <366000000>;
				remote-endpoint = <&camss_csiphy0_ep>;
			};
		};
	};
};

&{/soc@0/pinctrl@f100000} {
	cam0_default: cam0-default-state {
		reset-pins { pins = "gpio93"; function = "gpio"; drive-strength = <2>; bias-pull-down; };
		mclk-pins { pins = "gpio94"; function = "cam_mclk"; drive-strength = <16>; bias-disable; };
	};
};
DTS
dtc -q -I dts -O dtb -o "$pkg/board.dtb" "$pkg/src.dts"
d=$pkg/board.dtb; tlmm=/soc@0/pinctrl@f100000
old=$(fdtget -t u "$d" $tlmm gpio-reserved-ranges); new=$(echo "$old" | sed 's/ 83 25 / 83 9 96 5 103 2 107 1 /')
[ "$old" != "$new" ]; fdtput -t u "$d" $tlmm gpio-reserved-ranges $new; fdtget -t u "$d" $tlmm gpio-reserved-ranges
dtc -q -s -I dtb -O dts "$d" > "$pkg/r192.dts"; diff -u "$pkg/base.dts" "$pkg/r192.dts" > "$pkg/dtb.diff" || true
grep -c '^[+-]' "$pkg/dtb.diff"; sha256sum "$d"
