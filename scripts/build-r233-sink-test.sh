#!/bin/bash
# PRIVATE compile prototype. No tablet writes, no modifications to R200.
set -euo pipefail
src=/root/tb371fc/linux-6.12.114-r200
base=/root/tb371fc/build-6.12.114-r200
project='/mnt/c/Users/Sailren/Documents/ChatGPT/linux lenovo'
dest=/mnt/d/TB371FC-builds/r233-sink-test
work=$(mktemp -d /root/tb371fc/r233-sink-test.XXXXXX)
cp "$src/drivers/usb/typec/tcpm/qcom/"*.c "$src/drivers/usb/typec/tcpm/qcom/"*.h "$work/"
cp "$src/drivers/usb/typec/tcpm/tcpm.c" "$work/"
cp "$project/scripts/r232-dp-prep/sink-test.Kbuild" "$work/Makefile"
python3 "$project/scripts/r232-dp-prep/prepare-sink-test.py" "$work"
echo "Private prototype: $work"
make -C "$base" ARCH=arm64 LLVM=-18 M="$work" W=1 modules
mkdir -p "$dest"
cp "$work/"*.ko "$dest/"
sha256sum "$dest/"*.ko
