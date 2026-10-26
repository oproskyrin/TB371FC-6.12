#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
source_dir=/root/tb371fc/linux-6.12-donor
kernel_dir=/root/tb371fc/linux-6.12-donor-r37
base_out=/root/tb371fc/build-6.12-mmu-diag
out_dir=/root/tb371fc/build-6.12-r37-head-stage
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r37-head-stage-diagnostic

test -d "$source_dir/.git"
test -f "$base_out/.config"
test ! -e "$kernel_dir" || { echo "Refusing to overwrite $kernel_dir" >&2; exit 1; }
test ! -e "$out_dir" || { echo "Refusing to overwrite $out_dir" >&2; exit 1; }
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }

cp -a --reflink=auto "$source_dir" "$kernel_dir"
mkdir -p "$out_dir" "$package"
cp "$base_out/.config" "$out_dir/.config"

# r37 diagnostics are deliberately limited to head.S.  The older C markers
# wrote physical framebuffer/stage addresses after the MMU transition and can
# themselves fault.  Keep the proven identity map, but compile late markers out.
sed -i '/SYM_FUNC_START_LOCAL(__primary_switched)/,/SYM_FUNC_END(__primary_switched)/ s/CONFIG_TB371FC_EARLY_FB_MARKER/CONFIG_TB371FC_LATE_FB_MARKER/g' \
	"$kernel_dir/arch/arm64/kernel/head.S"
sed -i 's/CONFIG_TB371FC_EARLY_FB_MARKER/CONFIG_TB371FC_LATE_FB_MARKER/g' \
	"$kernel_dir/arch/arm64/kernel/setup.c" "$kernel_dir/init/main.c"

# Retained-RAM words were proven to be destroyed by the rollback path.  Make
# that helper a no-op and use only the visible framebuffer as the stage latch.
perl -0pi -e 's/(\n\t\.macro\s+tb371fc_early_stage_word stage\n).*?(\n\t\.endm\n)/$1$2/s' \
	"$kernel_dir/arch/arm64/kernel/head.S"

# Every pre-MMU marker now overwrites the full 2944x1840 splash instead of one
# 256-row band.  The final visible solid colour therefore identifies the last
# reached stage and cannot be confused with inherited V56.5 stripes.
perl -0pi -e 's/movz\tx1, #\\addr_lo\n\tmovk\tx1, #\\addr_hi, lsl #16/movz\tx1, #0x0000\n\tmovk\tx1, #0x9c00, lsl #16/' \
	"$kernel_dir/arch/arm64/kernel/head.S"
perl -0pi -e 's/movz\tx3, #0xc000\n\tmovk\tx3, #0x5, lsl #16/movz\tx3, #0x5000\n\tmovk\tx3, #0x29, lsl #16/' \
	"$kernel_dir/arch/arm64/kernel/head.S"

# Stage 83 (return from __pi_early_map_kernel) must be visible, not black.
sed -i 's/tb371fc_mmu_stage 0xff00, 0x0000, 83/tb371fc_mmu_stage 0xff00, 0xffff, 83/' \
	"$kernel_dir/arch/arm64/kernel/head.S"

"$kernel_dir/scripts/config" --file "$out_dir/.config" --enable TB371FC_EARLY_FB_MARKER
"$kernel_dir/scripts/config" --file "$out_dir/.config" --set-str LOCALVERSION '-tb371fc-r37-head-stage'
make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 olddefconfig
grep -qx 'CONFIG_TB371FC_EARLY_FB_MARKER=y' "$out_dir/.config"
grep -A18 'SYM_FUNC_START(__enable_mmu)' "$kernel_dir/arch/arm64/kernel/head.S" | grep -q 'mov.*x3, xzr'
! grep -q 'CONFIG_TB371FC_EARLY_FB_MARKER' "$kernel_dir/arch/arm64/kernel/setup.c"
! grep -q 'CONFIG_TB371FC_EARLY_FB_MARKER' "$kernel_dir/init/main.c"

make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 -j"$(nproc)" Image

install -m0644 "$out_dir/arch/arm64/boot/Image" "$package/Image"
install -m0644 "$out_dir/.config" "$package/config"
install -m0644 "$out_dir/System.map" "$package/System.map"
cat >"$package/BUILD-INFO.txt" <<'EOF'
TB371FC Linux 6.12.30 r37 head-stage diagnostic
- independent TGran bypass retained
- only safe head.S framebuffer markers enabled
- all pre-MMU bands changed to full-screen solid colours
- retained physical stage-word writes removed
- C/post-head physical markers disabled
- stage 83 changed from black to cyan
EOF
( cd "$package"; sha256sum Image config System.map BUILD-INFO.txt >SHA256SUMS; sha256sum -c SHA256SUMS )

