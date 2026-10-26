#!/usr/bin/env bash
# R161: community TFA98xx downstream driver (mainline-port patch 0003, sdm845-mainline
# 121d75c9) as an external module for the R159 kernel.
set -euo pipefail
p="$(cd "$(dirname "$0")/.." && pwd)"
src=/root/tb371fc/linux-6.12-donor-r118; out=/root/tb371fc/build-6.12-r159-audio
pkg=/mnt/d/TB371FC-builds/r161-tfa; mkdir -p "$pkg"
w=/root/tb371fc/r161-tfa98xx; rm -rf "$w"; mkdir -p "$w"; cd "$w"
git init -q .
git apply --include='sound/soc/codecs/tfa98xx-downstream/*' "$p/mainline-port/patches/0003-wip-ASoC-codecs-add-support-for-TFA98xx-based-on-dow.patch"
m="$w/sound/soc/codecs/tfa98xx-downstream"
# 7.1 -> 6.12 API
sed -i 's/snd_soc_component_to_dapm(/snd_soc_component_get_dapm(/g' "$m"/*.c
python3 "$p/scripts/r160-sound/tfa98xx-mtp-guard.py" "$m"
cat > "$m/Kbuild" <<'K'
obj-m += snd-soc-tfa98xx.o
snd-soc-tfa98xx-objs := tfa98xx.o tfa_container.o tfa_dsp.o tfa_init.o
ccflags-y += -Wno-error
K
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 M="$m" modules > "$pkg/tfa-build.log" 2>&1 || { grep -E "error" "$pkg/tfa-build.log" | head -30; exit 1; }
grep -c warning "$pkg/tfa-build.log" || true
modinfo -F vermagic "$m/snd-soc-tfa98xx.ko"; modinfo -F depends "$m/snd-soc-tfa98xx.ko"; modinfo -F alias "$m/snd-soc-tfa98xx.ko" | head; modinfo -F parm "$m/snd-soc-tfa98xx.ko" | head -20
cp "$m/snd-soc-tfa98xx.ko" "$pkg/"; sha256sum "$pkg/snd-soc-tfa98xx.ko"
