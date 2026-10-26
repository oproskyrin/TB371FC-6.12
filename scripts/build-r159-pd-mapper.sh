#!/usr/bin/env bash
# R159: unchanged upstream qcom_pd_mapper.c as external module for the R159 kernel.
set -euo pipefail
src=/root/tb371fc/linux-6.12-donor-r118
out=/root/tb371fc/build-6.12-r159-audio
pkg=/mnt/d/TB371FC-builds/r159-audio
m=/root/tb371fc/r159-pd-mapper; rm -rf "$m"; mkdir -p "$m"
cp "$src/drivers/soc/qcom/qcom_pd_mapper.c" "$m/"
echo 'obj-m += qcom_pd_mapper.o' > "$m/Kbuild"
echo 'ccflags-y += -I$(srctree)/drivers/soc/qcom' >> "$m/Kbuild"
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 M="$m" modules > "$pkg/pd-mapper-build.log" 2>&1 || { tail -20 "$pkg/pd-mapper-build.log"; exit 1; }
grep -i warn "$pkg/pd-mapper-build.log" || true
modinfo -F vermagic "$m/qcom_pd_mapper.ko"; modinfo -F depends "$m/qcom_pd_mapper.ko"
cp "$m/qcom_pd_mapper.ko" "$pkg/qcom_pd_mapper.ko"
sha256sum "$src/drivers/soc/qcom/qcom_pd_mapper.c" "$pkg/qcom_pd_mapper.ko"
