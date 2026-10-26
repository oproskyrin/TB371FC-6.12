#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

source_dir=/root/tb371fc/linux-6.12-donor-r41
kernel_dir=/root/tb371fc/linux-6.12-donor-r42
base_out=/root/tb371fc/build-6.12-r38-watchdog-handoff
out_dir=/root/tb371fc/build-6.12-r42-pre-start-kernel-checkpoint
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r42-pre-start-kernel-checkpoint

test -d "$source_dir/.git"
test -f "$base_out/.config"
test ! -e "$kernel_dir" || { echo "Refusing to overwrite $kernel_dir" >&2; exit 1; }
test ! -e "$out_dir" || { echo "Refusing to overwrite $out_dir" >&2; exit 1; }
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }

cp -a --reflink=auto "$source_dir" "$kernel_dir"
mkdir -p "$out_dir" "$package"
cp "$base_out/.config" "$out_dir/.config"

# r41 proved execution survives __pi_early_map_kernel (hardware result
# 2026-08-28: checkpoint fired, tablet returned to V56.6 unattended). r42
# moves the SAME single checkpoint to the very last instruction boundary in
# head.S: right before "bl start_kernel" in __primary_switched, after
# set_cpu_boot_mode_flag, kasan_early_init and finalise_el2 (the EL2/VHE
# transition) have all already run. Firing here proves the entire early-boot
# assembly path completes; not firing narrows the fault to
# set_cpu_boot_mode_flag/kasan_early_init/finalise_el2 for r43. Only one
# checkpoint may exist at a time, so the r41 site is reverted first.
python3 - "$kernel_dir/arch/arm64/kernel/head.S" <<'PYEOF'
import sys
path = sys.argv[1]
text = open(path, encoding='utf-8').read()

old_map_kernel_checkpoint = (
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
assert text.count(old_map_kernel_checkpoint) == 1, "r41 __pi_early_map_kernel checkpoint not found or not unique"
reverted = "\tbl\t__pi_early_map_kernel\t\t// Map and relocate the kernel\n"
text = text.replace(old_map_kernel_checkpoint, reverted)

needle = (
	"\tldp\tx29, x30, [sp], #16\n"
	"\tbl\tstart_kernel\n"
	"\tASM_BUG()\n"
	"SYM_FUNC_END(__primary_switched)\n"
)
assert text.count(needle) == 1, "start_kernel anchor not found or not unique"
replacement = (
	"\tldp\tx29, x30, [sp], #16\n"
	"#ifdef CONFIG_TB371FC_POST_MMU_RESET_CHECKPOINT\n"
	"\t/* Reached: set_cpu_boot_mode_flag, kasan_early_init and\n"
	"\t * finalise_el2 (EL2/VHE transition) have all returned. This is\n"
	"\t * the last instruction boundary in head.S before start_kernel.\n"
	"\t * PSCI SYSTEM_RESET (SMC 0x84000009). */\n"
	"\tmov\tx1, xzr\n"
	"\tmov\tx2, xzr\n"
	"\tmov\tx3, xzr\n"
	"\tmov\tx0, #0x09\n"
	"\tmovk\tx0, #0x8400, lsl #16\n"
	"\tsmc\t#0\n"
	"#endif\n"
	"\tbl\tstart_kernel\n"
	"\tASM_BUG()\n"
	"SYM_FUNC_END(__primary_switched)\n"
)
text = text.replace(needle, replacement)
open(path, 'w', encoding='utf-8').write(text)
PYEOF

"$kernel_dir/scripts/config" --file "$out_dir/.config" --enable TB371FC_EARLY_FB_MARKER
"$kernel_dir/scripts/config" --file "$out_dir/.config" --enable TB371FC_POST_MMU_RESET_CHECKPOINT
"$kernel_dir/scripts/config" --file "$out_dir/.config" --set-str LOCALVERSION '-tb371fc-r42-pre-start-kernel-checkpoint'
make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 olddefconfig
grep -qx 'CONFIG_TB371FC_EARLY_FB_MARKER=y' "$out_dir/.config"
grep -qx 'CONFIG_TB371FC_POST_MMU_RESET_CHECKPOINT=y' "$out_dir/.config"
# Exactly one checkpoint site: right before bl start_kernel.
test "$(grep -c 'movk.*x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/kernel/head.S")" = "1"
grep -B8 'movk.*x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/kernel/head.S" | grep -q 'last instruction boundary in head.S' \
	|| { grep -n -B12 'movk.*x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/kernel/head.S"; false; }
! grep -q '__pi_early_map_kernel returned' "$kernel_dir/arch/arm64/kernel/head.S"
! grep -q 'SCTLR_EL1 written, MMU enable instruction retired' "$kernel_dir/arch/arm64/kernel/head.S"

make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 -j"$(nproc)" Image

install -m0644 "$out_dir/arch/arm64/boot/Image" "$package/Image"
install -m0644 "$out_dir/.config" "$package/config"
install -m0644 "$out_dir/System.map" "$package/System.map"
cat >"$package/BUILD-INFO.txt" <<'EOF'
TB371FC Linux 6.12.30 r42 pre-start_kernel reset checkpoint diagnostic
- r41 __pi_early_map_kernel checkpoint reverted; hardware result 2026-08-28
  proved execution survives kernel relocation/cache maintenance/final page
  tables and returns to V56.6 unattended
- single PSCI SYSTEM_RESET checkpoint moved to the very last instruction
  boundary in head.S, right before "bl start_kernel" in __primary_switched
- covers set_cpu_boot_mode_flag, kasan_early_init and finalise_el2 (EL2/VHE
  transition) in this one step
- no physical framebuffer writes occur once the MMU is enabled
EOF
( cd "$package"; sha256sum Image config System.map BUILD-INFO.txt >SHA256SUMS; sha256sum -c SHA256SUMS )
stat -c 'Image=%s bytes' "$package/Image"
