#!/bin/bash
# No tablet install/load. Build isolated sources and shared host policy test.
set -euo pipefail
p='/mnt/c/Users/Sailren/Documents/ChatGPT/linux lenovo'
work=$(mktemp -d /root/tb371fc/r235-watchdog-only.XXXXXX)
cp "$p/scripts/r235-watchdog-only/"* "$work/"
clang-18 -Wall -Wextra -Werror "$work/test-policy.c" -o "$work/test-policy"
"$work/test-policy"
make -C /root/tb371fc/build-6.12.114-r200 ARCH=arm64 LLVM=-18 M="$work" W=1 modules
dest=/mnt/d/TB371FC-builds/r235-watchdog-only
mkdir -p "$dest"
cp "$work/r235-watchdog-only.ko" "$dest/"
sha256sum "$dest/r235-watchdog-only.ko"
