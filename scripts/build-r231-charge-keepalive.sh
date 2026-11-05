#!/bin/bash
set -euo pipefail
p='/mnt/c/Users/Sailren/Documents/ChatGPT/linux lenovo'
work=$(mktemp -d /root/tb371fc/r231-charge-keepalive.XXXXXX)
cp "$p/scripts/r231-charge-keepalive/"* "$work/"
make -C /root/tb371fc/build-6.12.114-r200 ARCH=arm64 LLVM=-18 M="$work" W=1 modules
mkdir -p /mnt/d/TB371FC-builds/r231-charge-keepalive
cp "$work/r231-charge-keepalive.ko" /mnt/d/TB371FC-builds/r231-charge-keepalive/
sha256sum /mnt/d/TB371FC-builds/r231-charge-keepalive/r231-charge-keepalive.ko
