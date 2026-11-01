#!/bin/bash
set -euo pipefail
p='/mnt/c/Users/Sailren/Documents/ChatGPT/linux lenovo'
work=$(mktemp -d /root/tb371fc/r209-qmp.XXXXXX)
cp /root/tb371fc/linux-6.12.114-r200/drivers/phy/qualcomm/*.h "$work/"
cp "$p/scripts/r209-qmp.Kbuild" "$work/Kbuild"
python3 "$p/scripts/prepare-r209-qmp-source.py" "$work"
make -C /root/tb371fc/build-6.12.114-r200 ARCH=arm64 LLVM=-18 M="$work" modules
mkdir -p /mnt/d/TB371FC-builds/r209-qmp
cp "$work/r209-qmp.ko" "$work/r209-qmp.c" "$work/stock-table-changes.txt" /mnt/d/TB371FC-builds/r209-qmp/
