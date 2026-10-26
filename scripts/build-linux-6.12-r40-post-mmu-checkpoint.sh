#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

source_dir=/root/tb371fc/linux-6.12-donor-r38
kernel_dir=/root/tb371fc/linux-6.12-donor-r40
base_out=/root/tb371fc/build-6.12-r38-watchdog-handoff
out_dir=/root/tb371fc/build-6.12-r40-post-mmu-checkpoint
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r40-post-mmu-checkpoint

test -d "$source_dir/.git"
test -f "$base_out/.config"
test ! -e "$kernel_dir" || { echo "Refusing to overwrite $kernel_dir" >&2; exit 1; }
test ! -e "$out_dir" || { echo "Refusing to overwrite $out_dir" >&2; exit 1; }
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }

cp -a --reflink=auto "$source_dir" "$kernel_dir"
mkdir -p "$out_dir" "$package"
cp "$base_out/.config" "$out_dir/.config"

# New, dedicated Kconfig symbol: a single PSCI SYSTEM_RESET checkpoint placed
# immediately after the SCTLR_EL1 write that enables the MMU, before any
# further code runs. This replaces the earlier idea of a post-MMU physical
# framebuffer write (proven unsafe: the physical pointer stops being valid
# once translation is active). A clean, fast reset after kexec -e proves
# execution survived the enable-MMU instant; a persistent hang proves it did
# not. Either outcome is informative and, unlike a hang, a successful reset
# also gets us back to V56.6 without a physical power cycle.
cat >>"$kernel_dir/arch/arm64/Kconfig.debug" <<'EOF'

config TB371FC_POST_MMU_RESET_CHECKPOINT
	bool "TB371FC single PSCI reset checkpoint right after MMU enable"
	default n
	help
	  Issue a PSCI SYSTEM_RESET SMC call immediately after the SCTLR_EL1
	  write in __enable_mmu, before any other instruction executes. Used
	  to localize a kexec early-boot hang to before or after the MMU
	  enable instant without relying on framebuffer writes, which are not
	  valid once address translation is active. Must remain disabled in
	  production kernels.
EOF

python3 - "$kernel_dir/arch/arm64/kernel/head.S" <<'PYEOF'
import sys
path = sys.argv[1]
text = open(path, encoding='utf-8').read()
needle = "\tset_sctlr_el1\tx0\n#ifdef CONFIG_TB371FC_POST_MMU_FB_MARKER\n\ttb371fc_mmu_stage 0xff00, 0xffff, 75\n#endif\n\n\tret\nSYM_FUNC_END(__enable_mmu)\n"
assert text.count(needle) == 1, "anchor not found or not unique"
replacement = (
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
open(path, 'w', encoding='utf-8').write(text.replace(needle, replacement))
PYEOF

"$kernel_dir/scripts/config" --file "$out_dir/.config" --enable TB371FC_EARLY_FB_MARKER
"$kernel_dir/scripts/config" --file "$out_dir/.config" --enable TB371FC_POST_MMU_RESET_CHECKPOINT
"$kernel_dir/scripts/config" --file "$out_dir/.config" --set-str LOCALVERSION '-tb371fc-r40-post-mmu-checkpoint'
make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 olddefconfig
grep -qx 'CONFIG_TB371FC_EARLY_FB_MARKER=y' "$out_dir/.config"
grep -qx 'CONFIG_TB371FC_POST_MMU_RESET_CHECKPOINT=y' "$out_dir/.config"
grep -q 'movk.*x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/kernel/head.S"
grep -q 'smc.*#0' "$kernel_dir/arch/arm64/kernel/head.S"

make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 -j"$(nproc)" Image

install -m0644 "$out_dir/arch/arm64/boot/Image" "$package/Image"
install -m0644 "$out_dir/.config" "$package/config"
install -m0644 "$out_dir/System.map" "$package/System.map"
cat >"$package/BUILD-INFO.txt" <<'EOF'
TB371FC Linux 6.12.30 r40 post-MMU reset checkpoint diagnostic
- r38 TGran bypass, pre-MMU stage 1-74 markers and watchdog handoff retained
- stage 75 physical framebuffer write replaced with a single PSCI
  SYSTEM_RESET SMC call placed right after the SCTLR_EL1 write in
  __enable_mmu, before any other instruction
- no physical framebuffer writes occur once the MMU is enabled
- a fast clean reset after kexec -e proves execution survived MMU enable;
  a persistent hang proves it did not
EOF
( cd "$package"; sha256sum Image config System.map BUILD-INFO.txt >SHA256SUMS; sha256sum -c SHA256SUMS )
stat -c 'Image=%s bytes' "$package/Image"
