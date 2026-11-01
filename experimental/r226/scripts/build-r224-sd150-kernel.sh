#!/bin/bash
# Single GCC table addition; retain exact R200 ABI so existing modules work.
set -euo pipefail
src=/root/tb371fc/linux-6.12.114-r200
out=/root/tb371fc/build-6.12.114-r200
dest=/mnt/d/TB371FC-builds/r224-sd150
mkdir -p "$dest"
test "$(cat "$out/include/config/kernel.release")" = 6.12.114-tb371fc-r199+
test "$(sha256sum /mnt/d/TB371FC-builds/r201-display/Image | cut -d' ' -f1)" = 92e8a30f3195660ad95f044e1d2ea2070c1acd37bfe456f67d90c203f10bb26b
grep -q 'F(150000000, P_GPLL0_OUT_MAIN, 4, 0, 0)' "$src/drivers/clk/qcom/gcc-sm8250.c"
cp "$out/Module.symvers" "$dest/Module.symvers.before"
cp "$out/.config" "$dest/kernel.config"
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 -j4 Image >"$dest/build.log" 2>&1
test "$(cat "$out/include/config/kernel.release")" = 6.12.114-tb371fc-r199+
if ! cmp "$out/Module.symvers" "$dest/Module.symvers.before"; then
 echo 'REFUSE package: module symbol CRC table changed'; exit 1
fi
cp "$out/arch/arm64/boot/Image" "$dest/Image"
sha256sum "$dest/Image"
echo 'R224 Image built; same ABI, GCC150MHz entry; NOT yet hardware tested'
