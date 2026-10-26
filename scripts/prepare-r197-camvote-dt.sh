#!/usr/bin/env bash
# R197 DT (CX+MX+MMCX at nominal) (test): R191 DT + "tb371fc,camvote" consumer node (RPMh MX, MMCX, GCC MMNOC TBU GDSCs) for
# the camera power experiment. No camera nodes.
set -euo pipefail
base=/mnt/d/TB371FC-builds/r190-mic/board.dtb; pkg=/mnt/d/TB371FC-builds/r197-camvote; mkdir -p "$pkg"
test "$(sha256sum "$base" | cut -d' ' -f1)" = 52a5d5775c04f88d3e424b767ad6e0f7e04540aace7df024b732d96e75c84bc6
dtc -q -s -I dtb -O dts "$base" > "$pkg/base.dts"
grep -q 'phandle = <0x34>' "$pkg/base.dts"; grep -q 'compatible = "qcom,gcc-sm8250"' "$pkg/base.dts"
cat "$pkg/base.dts" - > "$pkg/src.dts" <<'DTS'

/ {
	tb371fc-camvote {
		compatible = "tb371fc,camvote";
		power-domains = <0x34 0>, <0x34 8>, <0x34 6>;
		power-domain-names = "cx", "mx", "mmcx";
	};
};
DTS
dtc -q -I dts -O dtb -o "$pkg/board.dtb" "$pkg/src.dts"; sha256sum "$pkg/board.dtb"
p2=/mnt/d/TB371FC-builds/r197-autoboot; rm -rf $p2; mkdir -p $p2
cp /mnt/d/TB371FC-builds/r191-autoboot/Image /mnt/d/TB371FC-builds/r191-autoboot/initramfs.cpio.gz "$pkg/board.dtb" $p2/
cd $p2; tar -czf r197-payload.tar.gz Image board.dtb initramfs.cpio.gz; sha256sum board.dtb
