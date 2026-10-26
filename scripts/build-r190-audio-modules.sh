#!/usr/bin/env bash
# R190: WCD938x codec + LPASS RX/TX/VA macro modules for the R188 kernel (microphones).
# Separate build dir (copy of the R188 one); Module.symvers must stay identical for vmlinux symbols.
set -euo pipefail
src=/root/tb371fc/linux-6.12-donor-r118; base=/root/tb371fc/build-6.12-r187; out=/root/tb371fc/build-6.12-r190
pkg=/mnt/d/TB371FC-builds/r190-audio; mkdir -p "$pkg"
[ -d "$out" ] || cp -a "$base" "$out"
cd "$src"
scripts/config --file "$out/.config" -m SND_SOC_WCD938X_SDW -m SND_SOC_LPASS_RX_MACRO -m SND_SOC_LPASS_TX_MACRO -m SND_SOC_LPASS_VA_MACRO
make O="$out" ARCH=arm64 LLVM=-18 olddefconfig >/dev/null
grep -E "^CONFIG_(SND_SOC_WCD|SND_SOC_LPASS_(RX|TX|VA)_MACRO|SND_SOC_LPASS_MACRO_COMMON|REGMAP_SOUNDWIRE|SOUNDWIRE)" "$out/.config"
make O="$out" ARCH=arm64 LLVM=-18 -j"$(nproc)" modules > "$pkg/build.log" 2>&1 || { tail -30 "$pkg/build.log"; exit 1; }
join <(awk '{print $2, $1}' "$base/Module.symvers" | sort) <(awk '{print $2, $1}' "$out/Module.symvers" | sort) | awk '$2!=$3' > "$pkg/crc-changed.txt"
echo "changed CRCs: $(wc -l < "$pkg/crc-changed.txt")"
rm -f "$pkg"/*.ko
for m in sound/soc/codecs/snd-soc-wcd938x.ko sound/soc/codecs/snd-soc-wcd938x-sdw.ko sound/soc/codecs/snd-soc-wcd-mbhc.ko \
         sound/soc/codecs/snd-soc-wcd-classh.ko sound/soc/codecs/snd-soc-lpass-rx-macro.ko sound/soc/codecs/snd-soc-lpass-tx-macro.ko \
         sound/soc/codecs/snd-soc-lpass-va-macro.ko sound/soc/codecs/snd-soc-lpass-macro-common.ko drivers/base/regmap/regmap-sdw.ko; do
  [ -f "$out/$m" ] && cp "$out/$m" "$pkg/" || echo "missing $m"
done
ls "$pkg"/*.ko; for k in "$pkg"/*.ko; do echo "$(basename $k): $(modinfo -F depends $k)"; done
