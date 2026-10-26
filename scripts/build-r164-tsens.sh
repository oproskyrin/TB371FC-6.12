#!/usr/bin/env bash
# R164: unchanged upstream Qualcomm TSENS thermal sensor driver as an external module (R159 kernel).
set -euo pipefail
src=/root/tb371fc/linux-6.12-donor-r118; out=/root/tb371fc/build-6.12-r159-audio
pkg=/mnt/d/TB371FC-builds/r164-thermal; mkdir -p "$pkg"
w=/root/tb371fc/r164-tsens; rm -rf "$w"; m=$w/qcom; mkdir -p "$m"
cp "$src"/drivers/thermal/*.h "$w/"
cp "$src"/drivers/thermal/qcom/tsens*.[ch] "$m/"
printf 'obj-m += qcom_tsens.o\nqcom_tsens-y := tsens.o tsens-v2.o tsens-v1.o tsens-v0_1.o tsens-8960.o\nccflags-y += -I$(srctree)/drivers/thermal\n' > "$m/Kbuild"
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 M="$m" modules > "$pkg/tsens-build.log" 2>&1 || { grep -E "error|ERROR" "$pkg/tsens-build.log" | head; exit 1; }
modinfo -F vermagic "$m/qcom_tsens.ko"; modinfo -F depends "$m/qcom_tsens.ko"; modinfo -F alias "$m/qcom_tsens.ko" | grep -i "tsens-v2"
cp "$m/qcom_tsens.ko" "$pkg/"; sha256sum "$pkg/qcom_tsens.ko"
