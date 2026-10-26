#!/usr/bin/env bash
set -euo pipefail
p="$(cd "$(dirname "$0")/.." && pwd)"
src=/root/tb371fc/linux-6.12-donor-r118; out=/root/tb371fc/build-6.12-r159-audio; pkg=/mnt/d/TB371FC-builds/r166-diag; mkdir -p "$pkg"
m=/root/tb371fc/r166-memscan; rm -rf "$m"; mkdir -p "$m"; cp "$p/scripts/r166-memscan/tb371fc-memscan.c" "$m/"; echo 'obj-m += tb371fc-memscan.o' > "$m/Kbuild"
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 M="$m" modules > "$pkg/memscan-build.log" 2>&1 || { grep -E "error|warning" "$pkg/memscan-build.log" | head; exit 1; }
grep -i "warning" "$pkg/memscan-build.log" || true
cp "$m/tb371fc-memscan.ko" "$pkg/"; sha256sum "$pkg/tb371fc-memscan.ko"
