#!/usr/bin/env bash
set -euo pipefail
p="$(cd "$(dirname "$0")/.." && pwd)"
src=/root/tb371fc/linux-6.12-donor-r118; out=/root/tb371fc/build-6.12-r159-audio; pkg=/mnt/d/TB371FC-builds/r160-sound
m=/root/tb371fc/r160-lpass-vote; rm -rf "$m"; mkdir -p "$m"
cp "$p/scripts/r160-sound/tb371fc-lpass-vote.c" "$m/"; echo 'obj-m += tb371fc-lpass-vote.o' > "$m/Kbuild"
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 M="$m" modules > "$pkg/lpass-vote-build.log" 2>&1 || { grep -E "error|warning" "$pkg/lpass-vote-build.log" | head; exit 1; }
grep -i warning "$pkg/lpass-vote-build.log" || true
modinfo -F vermagic "$m/tb371fc-lpass-vote.ko"; cp "$m/tb371fc-lpass-vote.ko" "$pkg/"; sha256sum "$pkg/tb371fc-lpass-vote.ko"
