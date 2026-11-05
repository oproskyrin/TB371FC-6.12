#!/bin/bash
set -euo pipefail
p='/mnt/c/Users/Sailren/Documents/ChatGPT/linux lenovo'
work=$(mktemp -d /root/tb371fc/r230-sink-rearm.XXXXXX)
cp "$p/scripts/r230-sink-rearm/"* "$work/"
make -C /root/tb371fc/build-6.12.114-r200 ARCH=arm64 LLVM=-18 M="$work" modules
mkdir -p /mnt/d/TB371FC-builds/r230-sink-rearm
cp "$work/r230-sink-rearm.ko" /mnt/d/TB371FC-builds/r230-sink-rearm/
sha256sum /mnt/d/TB371FC-builds/r230-sink-rearm/r230-sink-rearm.ko
