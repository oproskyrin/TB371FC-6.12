#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

source_dir=/root/tb371fc/linux-6.12-donor-r42
kernel_dir=/root/tb371fc/linux-6.12-donor-r43
base_out=/root/tb371fc/build-6.12-r38-watchdog-handoff
out_dir=/root/tb371fc/build-6.12-r43-no-checkpoint-live-start-kernel
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r43-no-checkpoint-live-start-kernel

test -d "$source_dir/.git"
test -f "$base_out/.config"
test ! -e "$kernel_dir" || { echo "Refusing to overwrite $kernel_dir" >&2; exit 1; }
test ! -e "$out_dir" || { echo "Refusing to overwrite $out_dir" >&2; exit 1; }
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }

cp -a --reflink=auto "$source_dir" "$kernel_dir"
mkdir -p "$out_dir" "$package"
cp "$base_out/.config" "$out_dir/.config"

# r42 proved the entire head.S assembly path (kexec handoff, __enable_mmu,
# kernel relocation/mapping, set_cpu_boot_mode_flag, kasan_early_init,
# finalise_el2/EL2-VHE) completes without faulting: the checkpoint right
# before "bl start_kernel" fired and the tablet returned to V56.6 unattended.
# r43 removes the checkpoint entirely and lets start_kernel actually run, to
# see whether the generic C boot path (init/main.c) hangs or proceeds.
# There is no automatic recovery from this point on: if start_kernel hangs,
# only a physical power-cycle will bring V56.6 back, same as r39.
python3 - "$kernel_dir/arch/arm64/kernel/head.S" <<'PYEOF'
import sys
path = sys.argv[1]
text = open(path, encoding='utf-8').read()

needle = (
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
assert text.count(needle) == 1, "r42 pre-start_kernel checkpoint not found or not unique"
reverted = "\tldp\tx29, x30, [sp], #16\n\tbl\tstart_kernel\n\tASM_BUG()\nSYM_FUNC_END(__primary_switched)\n"
text = text.replace(needle, reverted)
open(path, 'w', encoding='utf-8').write(text)
PYEOF

"$kernel_dir/scripts/config" --file "$out_dir/.config" --enable TB371FC_EARLY_FB_MARKER
"$kernel_dir/scripts/config" --file "$out_dir/.config" --disable TB371FC_POST_MMU_RESET_CHECKPOINT
"$kernel_dir/scripts/config" --file "$out_dir/.config" --set-str LOCALVERSION '-tb371fc-r43-no-checkpoint'
make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 olddefconfig
grep -qx 'CONFIG_TB371FC_EARLY_FB_MARKER=y' "$out_dir/.config"
grep -q '^# CONFIG_TB371FC_POST_MMU_RESET_CHECKPOINT is not set' "$out_dir/.config"
! grep -q 'movk.*x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/kernel/head.S"
! grep -q 'PSCI SYSTEM_RESET' "$kernel_dir/arch/arm64/kernel/head.S"

make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 -j"$(nproc)" Image

install -m0644 "$out_dir/arch/arm64/boot/Image" "$package/Image"
install -m0644 "$out_dir/.config" "$package/config"
install -m0644 "$out_dir/System.map" "$package/System.map"
cat >"$package/BUILD-INFO.txt" <<'EOF'
TB371FC Linux 6.12.30 r43 no-checkpoint live start_kernel attempt
- r42's checkpoint (right before "bl start_kernel") removed entirely
- head.S is otherwise identical to r42: TGran bypass, watchdog handoff,
  reduced pre-MMU markers, no post-MMU framebuffer writes
- start_kernel now actually runs; no automatic recovery exists past this
  point (same as r39). A hang requires a physical power-cycle.
EOF
( cd "$package"; sha256sum Image config System.map BUILD-INFO.txt >SHA256SUMS; sha256sum -c SHA256SUMS )
stat -c 'Image=%s bytes' "$package/Image"
