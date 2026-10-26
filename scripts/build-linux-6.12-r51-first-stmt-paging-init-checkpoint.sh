#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

source_dir=/root/tb371fc/linux-6.12-donor-r47
kernel_dir=/root/tb371fc/linux-6.12-donor-r51
base_out=/root/tb371fc/build-6.12-r38-watchdog-handoff
out_dir=/root/tb371fc/build-6.12-r51-first-stmt-paging-init-checkpoint
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r51-first-stmt-paging-init-checkpoint

test -d "$source_dir/.git"
test -f "$base_out/.config"
test ! -e "$kernel_dir" || { echo "Refusing to overwrite $kernel_dir" >&2; exit 1; }
test ! -e "$out_dir" || { echo "Refusing to overwrite $out_dir" >&2; exit 1; }
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }

cp -a --reflink=auto "$source_dir" "$kernel_dir"
mkdir -p "$out_dir" "$package"
cp "$base_out/.config" "$out_dir/.config"

# r47/r49/r50 all placed the checkpoint right AFTER paging_init() returns
# (in setup_arch(), setup.c) and all three failed to fire under kexec --
# r49 additionally tried a flush_tlb_all() fix, r50 additionally tried
# stock PIL/firmware reserved-memory DTS nodes, neither changed the
# outcome. But that checkpoint site cannot distinguish "hangs inside
# paging_init()/map_mem()" from "hangs in whatever setup_arch() runs
# immediately after paging_init() returns" (memblock_allow_resize() inside
# paging_init() itself, or the next statements in setup_arch()). r51
# resolves that ambiguity: move the SAME single PSCI checkpoint to the
# very first statement inside paging_init(), before map_mem() runs at
# all, on top of r47's tree (no TLB fix, no extra DTS reservations, to
# isolate the placement question from the two already-refuted fixes).
#
# Firing here proves entry into paging_init() itself is reached (expected
# -- r46 already proved setup_machine_fdt() and everything before it is
# clean); the real signal is what a FOLLOW-UP checkpoint at the current
# r47/r49/r50 site would mean once this one is confirmed to fire: if r51
# fires, the fault is confirmed to be inside paging_init()/map_mem(), and
# further bisection belongs inside mmu.c. If r51 does NOT fire, the whole
# r47-r50 narrowing was wrong and the fault is actually between
# arm64_memblock_init() and paging_init(), which was never itself tested
# in isolation.
python3 - "$kernel_dir/arch/arm64/kernel/setup.c" <<'PYEOF'
import sys
path = sys.argv[1]
text = open(path, encoding='utf-8').read()

old_post_paging_init_checkpoint = (
	"\tpaging_init();\n"
	"#ifdef CONFIG_TB371FC_POST_MMU_RESET_CHECKPOINT\n"
	"\t/* Reached: paging_init() returned -- the real kernel page\n"
	"\t * tables (swapper linear map etc.) were built without\n"
	"\t * faulting. Single PSCI SYSTEM_RESET checkpoint (SMC\n"
	"\t * 0x84000009). */\n"
	"\tasm volatile(\n"
	"\t\t\"mov x1, xzr\\n\"\n"
	"\t\t\"mov x2, xzr\\n\"\n"
	"\t\t\"mov x3, xzr\\n\"\n"
	"\t\t\"mov x0, #0x09\\n\"\n"
	"\t\t\"movk x0, #0x8400, lsl #16\\n\"\n"
	"\t\t\"smc #0\\n\"\n"
	"\t\t::: \"x0\", \"x1\", \"x2\", \"x3\", \"memory\");\n"
	"#endif\n"
	"#ifdef CONFIG_TB371FC_LATE_FB_MARKER\n"
	"\ttb371fc_start_kernel_fb_marker(0xff8000ff, 30);\n"
	"#endif\n"
)
assert text.count(old_post_paging_init_checkpoint) == 1, "r47/r49/r50 post-paging_init checkpoint not found or not unique"
reverted = (
	"\tpaging_init();\n"
	"#ifdef CONFIG_TB371FC_LATE_FB_MARKER\n"
	"\ttb371fc_start_kernel_fb_marker(0xff8000ff, 30);\n"
	"#endif\n"
)
text = text.replace(old_post_paging_init_checkpoint, reverted)
open(path, 'w', encoding='utf-8').write(text)
PYEOF

python3 - "$kernel_dir/arch/arm64/mm/mmu.c" <<'PYEOF'
import sys
path = sys.argv[1]
text = open(path, encoding='utf-8').read()

old_entry = (
	"void __init paging_init(void)\n"
	"{\n"
	"\tmap_mem(swapper_pg_dir);\n"
)
assert text.count(old_entry) == 1, "paging_init() entry not found or not unique"
replacement = (
	"void __init paging_init(void)\n"
	"{\n"
	"#ifdef CONFIG_TB371FC_POST_MMU_RESET_CHECKPOINT\n"
	"\t/* Reached: entry to paging_init(), before map_mem() runs.\n"
	"\t * Isolates whether a hang at the r47/r49/r50 site (right\n"
	"\t * after paging_init() returns) is inside this function at\n"
	"\t * all, versus in whatever setup_arch() runs immediately\n"
	"\t * after. Single PSCI SYSTEM_RESET checkpoint (SMC\n"
	"\t * 0x84000009). */\n"
	"\tasm volatile(\n"
	"\t\t\"mov x1, xzr\\n\"\n"
	"\t\t\"mov x2, xzr\\n\"\n"
	"\t\t\"mov x3, xzr\\n\"\n"
	"\t\t\"mov x0, #0x09\\n\"\n"
	"\t\t\"movk x0, #0x8400, lsl #16\\n\"\n"
	"\t\t\"smc #0\\n\"\n"
	"\t\t::: \"x0\", \"x1\", \"x2\", \"x3\", \"memory\");\n"
	"#endif\n"
	"\tmap_mem(swapper_pg_dir);\n"
)
text = text.replace(old_entry, replacement)
open(path, 'w', encoding='utf-8').write(text)
PYEOF

"$kernel_dir/scripts/config" --file "$out_dir/.config" --enable TB371FC_EARLY_FB_MARKER
"$kernel_dir/scripts/config" --file "$out_dir/.config" --enable TB371FC_POST_MMU_RESET_CHECKPOINT
"$kernel_dir/scripts/config" --file "$out_dir/.config" --set-str LOCALVERSION '-tb371fc-r51-first-stmt-paging-init-checkpoint'
make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 olddefconfig
grep -qx 'CONFIG_TB371FC_EARLY_FB_MARKER=y' "$out_dir/.config"
grep -qx 'CONFIG_TB371FC_POST_MMU_RESET_CHECKPOINT=y' "$out_dir/.config"
test "$(grep -c 'movk x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/mm/mmu.c")" = "1"
grep -B15 'movk x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/mm/mmu.c" | grep -q 'entry to paging_init' \
	|| { grep -n -B15 'movk x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/mm/mmu.c"; false; }
! grep -q 'movk.*x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/kernel/setup.c"
! grep -q 'movk.*x0, #0x8400, lsl #16' "$kernel_dir/init/main.c"
! grep -q 'movk.*x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/kernel/head.S"

make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 -j"$(nproc)" Image

install -m0644 "$out_dir/arch/arm64/boot/Image" "$package/Image"
install -m0644 "$out_dir/.config" "$package/config"
install -m0644 "$out_dir/System.map" "$package/System.map"
cat >"$package/BUILD-INFO.txt" <<'EOF'
TB371FC Linux 6.12.30 r51 first-statement-of-paging_init() reset checkpoint diagnostic
- r47/r49/r50 all placed the checkpoint right after paging_init() returns
  and all three failed to fire under kexec (r49: + flush_tlb_all() fix,
  r50: + stock PIL/firmware reserved-memory DTS nodes; both refuted)
- r51 moves the SAME single PSCI checkpoint to the very first statement
  inside paging_init(), before map_mem() runs, on top of r47's tree (no
  TLB fix, no extra DTS reservations) to isolate whether the fault is
  inside paging_init()/map_mem() at all, or immediately after it returns
- firing here narrows the fault to inside paging_init()/map_mem() itself;
  not firing means the r47-r50 narrowing was wrong and the fault is
  actually between arm64_memblock_init() and paging_init()
EOF
( cd "$package"; sha256sum Image config System.map BUILD-INFO.txt >SHA256SUMS; sha256sum -c SHA256SUMS )
stat -c 'Image=%s bytes' "$package/Image"
