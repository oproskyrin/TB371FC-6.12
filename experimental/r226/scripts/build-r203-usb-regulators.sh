#!/bin/bash
set -euo pipefail
p='/mnt/c/Users/Sailren/Documents/ChatGPT/linux lenovo'
src=/root/tb371fc/linux-6.12.114-r200
out=/root/tb371fc/build-6.12.114-r200
work=$(mktemp -d /root/tb371fc/r203-usb-regulators.XXXXXX)
cp "$src/drivers/regulator/qcom-rpmh-regulator.c" "$work/r203-usb-regulators.c"
cp "$p/scripts/r203-usb-regulators.Kbuild" "$work/Kbuild"
patch -d "$work" -p1 < "$p/scripts/r203-usb-regulators.patch"
make -C "$out" ARCH=arm64 LLVM=-18 M="$work" modules
cp "$work/r203-usb-regulators.ko" /mnt/d/TB371FC-builds/r203-usb3/
