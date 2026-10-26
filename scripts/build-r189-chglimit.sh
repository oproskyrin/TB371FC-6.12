#!/usr/bin/env bash
# R189: charge limit module for the running R188 kernel (r187 build dir = R188 config).
set -euo pipefail
p="$(cd "$(dirname "$0")/.." && pwd)"
src=/root/tb371fc/linux-6.12-donor-r118; out=/root/tb371fc/build-6.12-r187
m=/root/tb371fc/r189-chglimit; rm -rf "$m"; mkdir -p "$m"
cp "$p/scripts/r189-chglimit/tb371fc-chglimit.c" "$m/"; echo 'obj-m := tb371fc-chglimit.o' > "$m/Kbuild"
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 M="$m" W=1 modules 2>&1 | grep -E "warning|error|LD" || true
modinfo -F vermagic "$m/tb371fc-chglimit.ko"
mkdir -p /mnt/d/TB371FC-builds/r189-chglimit; cp "$m/tb371fc-chglimit.ko" /mnt/d/TB371FC-builds/r189-chglimit/
