#!/usr/bin/env bash
set -euo pipefail
project="$(cd "$(dirname "$0")/.." && pwd)"
src=/root/tb371fc/linux-6.12-r134-panel
out=/root/tb371fc/build-6.12-r134-panel
pkg=/mnt/d/TB371FC-builds/r136-simplefb-control
test ! -e "$pkg"
mkdir "$pkg"
extra=$(mktemp -d /root/tb371fc/r136-simplefb.XXXXXX)
sha256sum "$out/.config" "$out/arch/arm64/boot/Image" > "$pkg/kernel-before.sha256"
cp "$src/drivers/video/fbdev/simplefb.c" "$extra/"
for file in fb_io_fops.c cfbcopyarea.c cfbfillrect.c cfbimgblt.c fb_draw.h; do
    cp "$src/drivers/video/fbdev/core/$file" "$extra/"
done
cp "$project/scripts/r136-simplefb.Kbuild" "$extra/Kbuild"
patch -d "$extra" -p1 < "$project/scripts/r136-simplefb-name.patch"
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 -j4 M="$extra" modules > "$pkg/build.log" 2>&1
cp "$extra/tb371fc_simplefb.ko" "$pkg/"
modinfo "$pkg/tb371fc_simplefb.ko" > "$pkg/modinfo.txt"
modinfo -F vermagic "$pkg/tb371fc_simplefb.ko" | grep -q '^6.12.30-tb371fc-r134-panel+ '
sha256sum -c "$pkg/kernel-before.sha256"
(cd "$pkg"; sha256sum tb371fc_simplefb.ko > SHA256SUMS; cat SHA256SUMS)
