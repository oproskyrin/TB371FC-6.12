#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

source_dir=/root/tb371fc/linux-6.12-donor-r40
kernel_dir=/root/tb371fc/linux-6.12-donor-r41
base_out=/root/tb371fc/build-6.12-r38-watchdog-handoff
out_dir=/root/tb371fc/build-6.12-r41-post-map-kernel-checkpoint
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r41-post-map-kernel-checkpoint

test -d "$source_dir/.git"
test -f "$base_out/.config"
test ! -e "$kernel_dir" || { echo "Refusing to overwrite $kernel_dir" >&2; exit 1; }
test ! -e "$out_dir" || { echo "Refusing to overwrite $out_dir" >&2; exit 1; }
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }

cp -a --reflink=auto "$source_dir" "$kernel_dir"
mkdir -p "$out_dir" "$package"
cp "$base_out/.config" "$out_dir/.config"

# r40 proved execution survives the SCTLR_EL1 write and at least one
# instruction fetch under translation (hardware result 2026-08-28: the
# checkpoint fired and the tablet returned to V56.6 within a minute, no
# physical power-cycle needed). r41 moves the SAME checkpoint further out:
# from right after set_sctlr_el1 in __enable_mmu, to right after
# __pi_early_map_kernel returns in __primary_switch. That call does the real
# work under the newly-enabled MMU (kernel relocation, cache maintenance,
# final page tables) and is a plausible place for a warm-kexec-specific
# failure (e.g. stale cachelines from the old kernel). Only one checkpoint
# may exist at a time: whichever is reached first fires and resets, so the
# earlier __enable_mmu checkpoint is reverted to plain code first.
python3 - "$kernel_dir/arch/arm64/kernel/head.S" <<'PYEOF'
import sys
path = sys.argv[1]
text = open(path, encoding='utf-8').read()

old_enable_mmu_checkpoint = (
	"\tset_sctlr_el1\tx0\n"
	"#ifdef CONFIG_TB371FC_POST_MMU_RESET_CHECKPOINT\n"
	"\t/* Reached: SCTLR_EL1 written, MMU enable instruction retired and\n"
	"\t * the next instruction fetched successfully under translation.\n"
	"\t * PSCI SYSTEM_RESET (SMC 0x84000009), no registers preserved. */\n"
	"\tmov\tx1, xzr\n"
	"\tmov\tx2, xzr\n"
	"\tmov\tx3, xzr\n"
	"\tmov\tx0, #0x09\n"
	"\tmovk\tx0, #0x8400, lsl #16\n"
	"\tsmc\t#0\n"
	"#endif\n"
	"\n\tret\nSYM_FUNC_END(__enable_mmu)\n"
)
assert text.count(old_enable_mmu_checkpoint) == 1, "r40 __enable_mmu checkpoint not found or not unique"
reverted = "\tset_sctlr_el1\tx0\n\n\tret\nSYM_FUNC_END(__enable_mmu)\n"
text = text.replace(old_enable_mmu_checkpoint, reverted)

needle = (
	"\tbl\t__pi_early_map_kernel\t\t// Map and relocate the kernel\n"
	"#ifdef CONFIG_TB371FC_POST_MMU_FB_MARKER\n"
	"\ttb371fc_mmu_stage 0xff00, 0xffff, 83\n"
	"#endif\n"
)
assert text.count(needle) == 1, "__pi_early_map_kernel anchor not found or not unique"
replacement = (
	"\tbl\t__pi_early_map_kernel\t\t// Map and relocate the kernel\n"
	"#ifdef CONFIG_TB371FC_POST_MMU_RESET_CHECKPOINT\n"
	"\t/* Reached: __pi_early_map_kernel returned. Kernel relocation and\n"
	"\t * final page tables under the enabled MMU completed without\n"
	"\t * faulting. PSCI SYSTEM_RESET (SMC 0x84000009). */\n"
	"\tmov\tx1, xzr\n"
	"\tmov\tx2, xzr\n"
	"\tmov\tx3, xzr\n"
	"\tmov\tx0, #0x09\n"
	"\tmovk\tx0, #0x8400, lsl #16\n"
	"\tsmc\t#0\n"
	"#endif\n"
)
text = text.replace(needle, replacement)
open(path, 'w', encoding='utf-8').write(text)
PYEOF

"$kernel_dir/scripts/config" --file "$out_dir/.config" --enable TB371FC_EARLY_FB_MARKER
"$kernel_dir/scripts/config" --file "$out_dir/.config" --enable TB371FC_POST_MMU_RESET_CHECKPOINT
"$kernel_dir/scripts/config" --file "$out_dir/.config" --set-str LOCALVERSION '-tb371fc-r41-post-map-kernel-checkpoint'
make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 olddefconfig
grep -qx 'CONFIG_TB371FC_EARLY_FB_MARKER=y' "$out_dir/.config"
grep -qx 'CONFIG_TB371FC_POST_MMU_RESET_CHECKPOINT=y' "$out_dir/.config"
# Exactly one checkpoint site: the one after __pi_early_map_kernel. The
# __enable_mmu site must be back to plain code.
test "$(grep -c 'movk.*x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/kernel/head.S")" = "1"
grep -B8 'movk.*x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/kernel/head.S" | grep -q '__pi_early_map_kernel returned' \
	|| { grep -n -B12 'movk.*x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/kernel/head.S"; false; }
! grep -q 'SCTLR_EL1 written, MMU enable instruction retired' "$kernel_dir/arch/arm64/kernel/head.S"

make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 -j"$(nproc)" Image

install -m0644 "$out_dir/arch/arm64/boot/Image" "$package/Image"
install -m0644 "$out_dir/.config" "$package/config"
install -m0644 "$out_dir/System.map" "$package/System.map"
cat >"$package/BUILD-INFO.txt" <<'EOF'
TB371FC Linux 6.12.30 r41 post-early-map-kernel reset checkpoint diagnostic
- r40 __enable_mmu checkpoint reverted; hardware result 2026-08-28 proved
  execution survives SCTLR_EL1 write and returns to V56.6 in ~1 minute
  unattended
- single PSCI SYSTEM_RESET checkpoint moved to right after
  __pi_early_map_kernel returns in __primary_switch (relocation/cache
  maintenance/final page tables under the enabled MMU)
- no physical framebuffer writes occur once the MMU is enabled
EOF
( cd "$package"; sha256sum Image config System.map BUILD-INFO.txt >SHA256SUMS; sha256sum -c SHA256SUMS )
stat -c 'Image=%s bytes' "$package/Image"
