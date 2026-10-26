#!/usr/bin/env bash
# R160: unchanged upstream LPASS LPI pinctrl (holds LPASS_HW_MACRO/DCODEC votes via q6afe-clocks).
set -euo pipefail
src=/root/tb371fc/linux-6.12-donor-r118
out=/root/tb371fc/build-6.12-r159-audio
pkg=/mnt/d/TB371FC-builds/r160-sound
m=/root/tb371fc/r160-lpi-pinctrl; rm -rf "$m"; mkdir -p "$m"
cp "$src/drivers/pinctrl/qcom/pinctrl-lpass-lpi.c" "$src/drivers/pinctrl/qcom/pinctrl-lpass-lpi.h" "$src/drivers/pinctrl/qcom/pinctrl-sm8250-lpass-lpi.c" "$m/"
printf 'obj-m += pinctrl-lpass-lpi.o pinctrl-sm8250-lpass-lpi.o\nccflags-y += -I$(srctree)/drivers/pinctrl/qcom -I$(srctree)/drivers/pinctrl\n' > "$m/Kbuild"
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 M="$m" modules > "$pkg/lpi-build.log" 2>&1 || { grep -E "error|ERROR" "$pkg/lpi-build.log" | head; exit 1; }
for k in pinctrl-lpass-lpi pinctrl-sm8250-lpass-lpi; do modinfo -F vermagic "$m/$k.ko"; modinfo -F depends "$m/$k.ko"; cp "$m/$k.ko" "$pkg/"; done
sha256sum "$src/drivers/pinctrl/qcom/pinctrl-lpass-lpi.c" "$src/drivers/pinctrl/qcom/pinctrl-sm8250-lpass-lpi.c" "$pkg"/pinctrl-*.ko
