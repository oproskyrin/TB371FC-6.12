#!/usr/bin/env bash
# R184: framebuffer screenshot module for the running 6.12 (R179 kernel, r159-audio build tree).
set -euo pipefail
p="$(cd "$(dirname "$0")/.." && pwd)"
src=/root/tb371fc/linux-6.12-donor-r118; out=/root/tb371fc/build-6.12-r159-audio
m=/root/tb371fc/r184-fbgrab; rm -rf "$m"; mkdir -p "$m"
cp "$p/scripts/r184-fbgrab/tb371fc-fbgrab.c" "$m/"; echo 'obj-m := tb371fc-fbgrab.o' > "$m/Kbuild"
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 M="$m" modules 2>&1 | tail -5
modinfo -F vermagic "$m/tb371fc-fbgrab.ko"
mkdir -p /mnt/d/TB371FC-builds/r184-fbgrab; cp "$m/tb371fc-fbgrab.ko" /mnt/d/TB371FC-builds/r184-fbgrab/
