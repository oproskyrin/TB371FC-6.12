#!/usr/bin/env bash
set -euo pipefail
p="$(cd "$(dirname "$0")/.." && pwd)"
src=/root/tb371fc/linux-6.12-donor-r118; out=/root/tb371fc/build-6.12-r190
m=/root/tb371fc/r194-campeek; rm -rf "$m"; mkdir -p "$m"; cp "$p/scripts/r194-campeek/"*.c "$m/"; echo "obj-m := tb371fc-campeek.o tb371fc-camxo.o tb371fc-camvote.o" > "$m/Kbuild"
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 M="$m" modules 2>&1 | grep -E "error|warning" || true
mkdir -p /mnt/d/TB371FC-builds/r194-campeek; cp "$m/"*.ko /mnt/d/TB371FC-builds/r194-campeek/
