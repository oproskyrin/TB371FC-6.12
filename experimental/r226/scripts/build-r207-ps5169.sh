#!/bin/bash
set -euo pipefail
p='/mnt/c/Users/Sailren/Documents/ChatGPT/linux lenovo'
work=$(mktemp -d /root/tb371fc/r207-ps5169.XXXXXX)
cp "$p/scripts/r207-ps5169/"* "$work/"
cp /root/tb371fc/linux-6.12.114-r200/drivers/usb/typec/mux.h "$work/"
make -C /root/tb371fc/build-6.12.114-r200 ARCH=arm64 LLVM=-18 M="$work" modules
mkdir -p /mnt/d/TB371FC-builds/r207-ps5169
cp "$work/r207-ps5169.ko" /mnt/d/TB371FC-builds/r207-ps5169/
