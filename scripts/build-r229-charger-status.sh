#!/bin/bash
set -euo pipefail
p='/mnt/c/Users/Sailren/Documents/ChatGPT/linux lenovo'
work=$(mktemp -d /root/tb371fc/r229-charger-status.XXXXXX)
cp "$p/scripts/r229-charger-status/"* "$work/"
make -C /root/tb371fc/build-6.12.114-r200 ARCH=arm64 LLVM=-18 M="$work" modules
dest=${R229_DEST:-/mnt/d/TB371FC-builds/r229-charger-status}
mkdir -p "$dest"
cp "$work/r229-charger-status.ko" "$dest/"
sha256sum "$dest/r229-charger-status.ko"
