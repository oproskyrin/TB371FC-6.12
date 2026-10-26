#!/usr/bin/env bash
# R160: TB371FC machine driver (sm8250.c + PRI_TDM) and placeholder codec spdif-dit,
# external modules for the R159 kernel. Image is unchanged.
set -euo pipefail
p="$(cd "$(dirname "$0")/.." && pwd)"
src=/root/tb371fc/linux-6.12-donor-r118
out=/root/tb371fc/build-6.12-r159-audio
pkg=/mnt/d/TB371FC-builds/r160-sound
m=/root/tb371fc/r160-sound-modules; rm -rf "$m"; mkdir -p "$m" "$pkg"
python3 "$p/scripts/r160-sound/make-tb371fc-sndcard.py" "$src/sound/soc/qcom/sm8250.c" "$m/tb371fc-sndcard.c"
cp "$src/sound/soc/codecs/spdif_transmitter.c" "$m/"
cat > "$m/Kbuild" <<'K'
obj-m += snd-soc-tb371fc.o snd-soc-spdif-tx.o
snd-soc-tb371fc-y := tb371fc-sndcard.o
snd-soc-spdif-tx-y := spdif_transmitter.o
ccflags-y += -I$(srctree)/sound/soc/qcom
K
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 M="$m" modules > "$pkg/modules-build.log" 2>&1 || { grep -E "error|ERROR" "$pkg/modules-build.log" | head -20; exit 1; }
grep -i -E "warning" "$pkg/modules-build.log" || true
diff -u "$src/sound/soc/qcom/sm8250.c" "$m/tb371fc-sndcard.c" > "$pkg/tb371fc-sndcard.diff" || true
for k in snd-soc-tb371fc snd-soc-spdif-tx; do modinfo -F vermagic "$m/$k.ko"; modinfo -F depends "$m/$k.ko"; cp "$m/$k.ko" "$pkg/"; done
sha256sum "$pkg"/*.ko
