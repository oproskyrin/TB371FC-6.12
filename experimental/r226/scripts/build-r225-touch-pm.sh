#!/bin/bash
set -euo pipefail
p='/mnt/c/Users/Sailren/Documents/ChatGPT/linux lenovo'
work=$(mktemp -d /root/tb371fc/r225-touch-pm.XXXXXX)
cp "$p/scripts/r225-touch-pm/"* "$work/"
make -C /root/tb371fc/build-6.12.114-r200 ARCH=arm64 LLVM=-18 M="$work" modules
mkdir -p /mnt/d/TB371FC-builds/r225-touch-pm
cp "$work/r225-touch-pm.ko" /mnt/d/TB371FC-builds/r225-touch-pm/
