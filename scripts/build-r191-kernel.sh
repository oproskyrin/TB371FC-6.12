#!/usr/bin/env bash
# R191 kernel: R188 + REGMAP_IRQ (wcd938x) + upstream LPASS LPI pinctrl (GENERIC_PINCTRL_GROUPS /
# GENERIC_PINMUX_FUNCTIONS built in) + R190 audio modules. Reports Module.symvers CRC changes.
set -euo pipefail
src=/root/tb371fc/linux-6.12-donor-r118; base=/root/tb371fc/build-6.12-r187; out=/root/tb371fc/build-6.12-r190
pkg=/mnt/d/TB371FC-builds/r191-kernel; mkdir -p "$pkg"
cd "$src"
scripts/config --file "$out/.config" -e REGMAP_IRQ -m PINCTRL_LPASS_LPI -m PINCTRL_SM8250_LPASS_LPI \
  -m SND_SOC_WCD938X_SDW -m SND_SOC_LPASS_RX_MACRO -m SND_SOC_LPASS_TX_MACRO -m SND_SOC_LPASS_VA_MACRO
make O="$out" ARCH=arm64 LLVM=-18 olddefconfig >/dev/null
grep -E "^CONFIG_(REGMAP_IRQ|GENERIC_PINCTRL_GROUPS|GENERIC_PINMUX_FUNCTIONS|GENERIC_PINCONF|PINCTRL_LPASS_LPI|PINCTRL_SM8250_LPASS_LPI)=" "$out/.config"
make O="$out" ARCH=arm64 LLVM=-18 -j"$(nproc)" Image modules > "$pkg/build.log" 2>&1 || { tail -30 "$pkg/build.log"; exit 1; }
cp "$out/arch/arm64/boot/Image" "$pkg/Image"; sha256sum "$pkg/Image"
join <(awk '{print $2, $1}' "$base/Module.symvers" | sort) <(awk '{print $2, $1}' "$out/Module.symvers" | sort) | awk '$2!=$3' > "$pkg/crc-changed.txt"
echo "changed CRCs: $(wc -l < "$pkg/crc-changed.txt")"; head -30 "$pkg/crc-changed.txt"
