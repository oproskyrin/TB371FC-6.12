#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

source_dir=/root/tb371fc/linux-6.12-donor-r37
kernel_dir=/root/tb371fc/linux-6.12-donor-r38
base_out=/root/tb371fc/build-6.12-r37-head-stage
out_dir=/root/tb371fc/build-6.12-r38-watchdog-handoff
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r38-watchdog-handoff

test -d "$source_dir/.git"
test -f "$base_out/.config"
test ! -e "$kernel_dir" || { echo "Refusing to overwrite $kernel_dir" >&2; exit 1; }
test ! -e "$out_dir" || { echo "Refusing to overwrite $out_dir" >&2; exit 1; }
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }

cp -a --reflink=auto "$source_dir" "$kernel_dir"
mkdir -p "$out_dir" "$package"
cp "$base_out/.config" "$out_dir/.config"

# r37 painted all 21.7 MiB at every stage.  Retain a visible 16-line latch
# (2944 * 16 * 4 / 8 = 0x5c00 paired stores), reducing pre-kernel MMIO by 99%.
sed -i 's/movz\tx3, #0x5000/movz\tx3, #0x5c00/; s/movk\tx3, #0x29, lsl #16/nop/' \
	"$kernel_dir/arch/arm64/kernel/head.S"
sed -i 's/movz\tx8, #0x5000/movz\tx8, #0x5c00/; s/movk\tx8, #0x29, lsl #16/nop/' \
	"$kernel_dir/arch/arm64/kernel/head.S"

# Physical framebuffer accesses after SCTLR_EL1.M becomes active are not a
# valid diagnostic primitive.  Compile out stage 75 and all return-path marks.
sed -i '/set_sctlr_el1/,/SYM_FUNC_END(__enable_mmu)/ s/CONFIG_TB371FC_EARLY_FB_MARKER/CONFIG_TB371FC_POST_MMU_FB_MARKER/g' \
	"$kernel_dir/arch/arm64/kernel/head.S"
sed -i '/SYM_FUNC_START_LOCAL(__primary_switch)/,/SYM_FUNC_END(__primary_switch)/ s/CONFIG_TB371FC_EARLY_FB_MARKER/CONFIG_TB371FC_POST_MMU_FB_MARKER/g' \
	"$kernel_dir/arch/arm64/kernel/head.S"

"$kernel_dir/scripts/config" --file "$out_dir/.config" --enable TB371FC_EARLY_FB_MARKER
"$kernel_dir/scripts/config" --file "$out_dir/.config" --set-str LOCALVERSION '-tb371fc-r38-wdog-handoff'
make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 olddefconfig
grep -qx 'CONFIG_TB371FC_EARLY_FB_MARKER=y' "$out_dir/.config"
grep -q 'movz.*x3, #0x5c00' "$kernel_dir/arch/arm64/kernel/head.S"
grep -q 'movz.*x8, #0x5c00' "$kernel_dir/arch/arm64/kernel/head.S"

make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 -j"$(nproc)" Image

install -m0644 "$out_dir/arch/arm64/boot/Image" "$package/Image"
install -m0644 "$out_dir/.config" "$package/config"
install -m0644 "$out_dir/System.map" "$package/System.map"
cat >"$package/BUILD-INFO.txt" <<'EOF'
TB371FC Linux 6.12.30 r38 watchdog handoff diagnostic
- r37 TGran bypass and pre-MMU stage coverage retained
- each marker reduced from 21.7 MiB to a 2944x16 strip
- all physical framebuffer writes after SCTLR_EL1.M removed
- first-stage watchdog is disabled through its SCM-backed sysfs gate
EOF
( cd "$package"; sha256sum Image config System.map BUILD-INFO.txt >SHA256SUMS; sha256sum -c SHA256SUMS )
