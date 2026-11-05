#!/bin/bash
# Offline replacement provider, must NEVER be loaded beside live R203.
set -euo pipefail
p='/mnt/c/Users/Sailren/Documents/ChatGPT/linux lenovo'
src=/root/tb371fc/linux-6.12.114-r200
out=/root/tb371fc/build-6.12.114-r200
work=$(mktemp -d /root/tb371fc/r237-usb-regulators.XXXXXX)
cp "$src/drivers/regulator/qcom-rpmh-regulator.c" "$work/r203-usb-regulators.c"
cp "$p/scripts/r203-usb-regulators.Kbuild" "$work/Kbuild"
patch -d "$work" -p1 < "$p/scripts/r203-usb-regulators.patch"
python3 "$p/scripts/r237-pd-integration/prepare-regulator.py" "$work/r203-usb-regulators.c"
make -C "$out" ARCH=arm64 LLVM=-18 M="$work" W=1 modules
dest=/mnt/d/TB371FC-builds/r237-pd-integration
mkdir -p "$dest"
cp "$work/r203-usb-regulators.ko" "$dest/"
sha256sum "$dest/r203-usb-regulators.ko"
