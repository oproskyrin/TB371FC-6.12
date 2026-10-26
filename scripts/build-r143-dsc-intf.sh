#!/usr/bin/env bash
# R143: R137 native kernel + DPU DSC bonded-intf fix (one source change).
# LOCALVERSION is unchanged so the R139 initramfs modules (same vermagic) load.
set -euo pipefail
project="$(cd "$(dirname "$0")/.." && pwd)"
basesrc=/root/tb371fc/linux-6.12-r137-native
baseout=/root/tb371fc/build-6.12-r137-native
src=/root/tb371fc/linux-6.12-r143-dsc-intf
out=/root/tb371fc/build-6.12-r143-dsc-intf
pkg=/mnt/d/TB371FC-builds/r143-dsc-intf
patch="$project/mainline-port/backports/linux-6.12/0010-dpu-dsc-keep-bonded-intf-count.patch"
if [ "${1:-}" != --resume ]; then
    test ! -e "$src"; test ! -e "$out"; test ! -e "$pkg"
    mkdir -p "$pkg"
    cp -a --reflink=auto "$basesrc" "$src"
    cp -a --reflink=auto "$baseout" "$out"
    (cd "$src"; patch -p1 --dry-run < "$patch" && patch -p1 < "$patch")
fi
grep -q "topology.num_intf = intf_count;" "$src/drivers/gpu/drm/msm/disp/dpu1/dpu_encoder.c"
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 -j8 Image > "$pkg/build.log" 2>&1
cp "$out/arch/arm64/boot/Image" "$pkg/Image"
old=$(grep -a -o -m1 "Linux version 6.12.30-tb371fc-r137-native+ " /mnt/d/TB371FC-builds/r141-dpu-only/Image | head -1 || true)
new=$(grep -a -o -m1 "Linux version 6.12.30-tb371fc-r137-native+ " "$pkg/Image" | head -1 || true)
test -n "$old"; test "$old" = "$new"
cp /mnt/d/TB371FC-builds/r141-dpu-only/board.dtb /mnt/d/TB371FC-builds/r141-dpu-only/initramfs.cpio.gz "$pkg/"
cp "$patch" "$pkg/"
(cd "$src"; git diff -- drivers/gpu/drm/msm/disp/dpu1/dpu_encoder.c) > "$pkg/dpu_encoder.diff"
cd "$pkg"
sha256sum Image board.dtb initramfs.cpio.gz > SHA256SUMS
tar -czf r143-payload.tar.gz Image board.dtb initramfs.cpio.gz
sha256sum r143-payload.tar.gz >> SHA256SUMS
cat SHA256SUMS
tail -3 build.log
