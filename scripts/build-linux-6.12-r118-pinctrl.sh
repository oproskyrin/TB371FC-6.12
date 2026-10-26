#!/usr/bin/env bash
set -euo pipefail
src=/root/tb371fc/linux-6.12-donor-r118
out=/root/tb371fc/build-6.12-r118-pinctrl
pkg=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r118-pinctrl
test ! -e "$src"
test ! -e "$out"
test ! -e "$pkg"
cp -a --reflink=auto /root/tb371fc/linux-6.12-donor-r68 "$src"
mkdir -p "$out" "$pkg"
cp /root/tb371fc/build-6.12-r68-memblock-checkpoint/.config "$out/.config"
# Remove only the diagnostic reset; retain early page-table pool implementation.
python3 - "$src/arch/arm64/kernel/setup.c" <<'PY'
import pathlib,sys
p=pathlib.Path(sys.argv[1]); s=p.read_text()
assert s.count('"smc #0\\n"') == 1
s=s.replace('"smc #0\\n"', '"nop\\n"')
p.write_text(s)
PY
"$src/scripts/config" --file "$out/.config" --enable PINCTRL_MSM --enable PINCTRL_SM8250 --set-str LOCALVERSION '-tb371fc-r118-pinctrl'
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 olddefconfig
grep -qx CONFIG_PINCTRL_MSM=y "$out/.config"
grep -qx CONFIG_PINCTRL_SM8250=y "$out/.config"
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 -j8 Image >"$pkg/compile.log" 2>&1
cp "$out/arch/arm64/boot/Image" "$out/.config" "$out/System.map" "$pkg/"
sha256sum "$pkg/Image"
