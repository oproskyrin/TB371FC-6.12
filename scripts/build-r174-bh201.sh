#!/usr/bin/env bash
# R174: TB371FC BH201 microSD bridge test module (external, against the R159 kernel build).
set -euo pipefail
p="$(cd "$(dirname "$0")/.." && pwd)"
src=/root/tb371fc/linux-6.12-donor-r118; out=/root/tb371fc/build-6.12-r159-audio
pkg=/mnt/d/TB371FC-builds/r174-bh201; mkdir -p "$pkg"
m=/root/tb371fc/r174-bh201; rm -rf "$m"; mkdir -p "$m"
cp "$p"/scripts/r174-bh201/* "$m/"
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 M="$m" modules > "$pkg/build.log" 2>&1 || { grep -E "error|warning" "$pkg/build.log" | head -20; exit 1; }
grep -i warning "$pkg/build.log" || true
modinfo -F vermagic "$m/tb371fc-bh201.ko"
cp "$m/tb371fc-bh201.ko" "$pkg/"; sha256sum "$pkg/tb371fc-bh201.ko"
