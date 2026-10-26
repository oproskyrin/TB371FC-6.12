#!/usr/bin/env bash
set -euo pipefail
project="$(cd "$(dirname "$0")/.." && pwd)"
src=/root/tb371fc/linux-6.12-r137-native
out=/root/tb371fc/build-6.12-r137-native
pkg=/mnt/d/TB371FC-builds/r139-panel-gates
if [ -e "$pkg" ]; then test "${1:-}" = --retry; else mkdir "$pkg"; fi
extra=$(mktemp -d /root/tb371fc/r139-panel.XXXXXX)
cp "$src/drivers/gpu/drm/panel/panel-novatek-nt36523.c" "$extra/r139_panel.c"
cp "$project/scripts/r139-panel.Kbuild" "$extra/Kbuild"
git -C "$extra" apply --recount --unidiff-zero "$project/mainline-port/backports/linux-6.12/0004-r139-panel-probe-gates.patch"
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 -j4 M="$extra" modules > "$pkg/build.log" 2>&1
cp "$extra/r139_panel.c" "$extra/r139_panel.ko" "$pkg/"
modinfo "$pkg/r139_panel.ko" > "$pkg/modinfo.txt"
modinfo -F vermagic "$pkg/r139_panel.ko" | grep -q '^6.12.30-tb371fc-r137-native+ '
(cd "$pkg"; sha256sum r139_panel.c r139_panel.ko > SHA256SUMS; cat SHA256SUMS)
