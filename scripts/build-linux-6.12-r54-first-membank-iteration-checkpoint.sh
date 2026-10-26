#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

source_dir=/root/tb371fc/linux-6.12-donor-r47
kernel_dir=/root/tb371fc/linux-6.12-donor-r54
base_out=/root/tb371fc/build-6.12-r38-watchdog-handoff
out_dir=/root/tb371fc/build-6.12-r54-first-membank-iteration-checkpoint
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r54-first-membank-iteration-checkpoint

test -d "$source_dir/.git"
test -f "$base_out/.config"
test ! -e "$kernel_dir" || { echo "Refusing to overwrite $kernel_dir" >&2; exit 1; }
test ! -e "$out_dir" || { echo "Refusing to overwrite $out_dir" >&2; exit 1; }
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }

cp -a --reflink=auto "$source_dir" "$kernel_dir"
mkdir -p "$out_dir" "$package"
cp "$base_out/.config" "$out_dir/.config"

# r53 proved the fault is inside the for_each_mem_range() loop body itself
# (checkpoint right before the loop fired; r52's checkpoint right after the
# loop hung). The loop calls __map_memblock() once per memblock region.
# Since a plain PSCI SYSTEM_RESET checkpoint carries no state across the
# reset, the simplest next test is to place the checkpoint unconditionally
# right after the __map_memblock() call, still inside the loop body, before
# the loop can advance to a second iteration. This tests specifically
# whether mapping the FIRST memblock region already faults:
#   - fires -> the first region's __map_memblock() call is clean; the fault
#     is in a later iteration (a specific, not-yet-identified region)
#   - does not fire -> the very first memblock region's __map_memblock()
#     call itself faults
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

old_loop_body = (
	"\t\t__map_memblock(pgdp, start, end, pgprot_tagged(PAGE_KERNEL),\n"
	"\t\t\t       flags);\n"
	"\t}\n"
)
assert text.count(old_loop_body) == 1, "__map_memblock loop body not found or not unique"
replacement = (
	"\t\t__map_memblock(pgdp, start, end, pgprot_tagged(PAGE_KERNEL),\n"
	"\t\t\t       flags);\n"
	"#ifdef CONFIG_TB371FC_POST_MMU_RESET_CHECKPOINT\n"
	"\t\t/* Reached: the FIRST __map_memblock() call inside the\n"
	"\t\t * for_each_mem_range() loop returned -- the first memblock\n"
	"\t\t * region was mapped without faulting. Unconditional inside\n"
	"\t\t * the loop body, so this fires after iteration 1 and halts\n"
	"\t\t * before any later iteration can run. Single PSCI\n"
	"\t\t * SYSTEM_RESET checkpoint (SMC 0x84000009). */\n"
	"\t\tasm volatile(\n"
	"\t\t\t\"mov x1, xzr\\n\"\n"
	"\t\t\t\"mov x2, xzr\\n\"\n"
	"\t\t\t\"mov x3, xzr\\n\"\n"
	"\t\t\t\"mov x0, #0x09\\n\"\n"
	"\t\t\t\"movk x0, #0x8400, lsl #16\\n\"\n"
	"\t\t\t\"smc #0\\n\"\n"
	"\t\t\t::: \"x0\", \"x1\", \"x2\", \"x3\", \"memory\");\n"
	"#endif\n"
	"\t}\n"
)
text = text.replace(old_loop_body, replacement)
open(path, 'w', encoding='utf-8').write(text)
PYEOF

"$kernel_dir/scripts/config" --file "$out_dir/.config" --enable TB371FC_EARLY_FB_MARKER
"$kernel_dir/scripts/config" --file "$out_dir/.config" --enable TB371FC_POST_MMU_RESET_CHECKPOINT
"$kernel_dir/scripts/config" --file "$out_dir/.config" --set-str LOCALVERSION '-tb371fc-r54-first-membank-iteration-checkpoint'
make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 olddefconfig
grep -qx 'CONFIG_TB371FC_EARLY_FB_MARKER=y' "$out_dir/.config"
grep -qx 'CONFIG_TB371FC_POST_MMU_RESET_CHECKPOINT=y' "$out_dir/.config"
test "$(grep -c 'movk x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/mm/mmu.c")" = "1"
grep -B15 'movk x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/mm/mmu.c" | grep -q 'FIRST __map_memblock' \
	|| { grep -n -B15 'movk x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/mm/mmu.c"; false; }
! grep -q 'movk.*x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/kernel/setup.c"
! grep -q 'movk.*x0, #0x8400, lsl #16' "$kernel_dir/init/main.c"
! grep -q 'movk.*x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/kernel/head.S"

make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 -j"$(nproc)" Image

install -m0644 "$out_dir/arch/arm64/boot/Image" "$package/Image"
install -m0644 "$out_dir/.config" "$package/config"
install -m0644 "$out_dir/System.map" "$package/System.map"
cat >"$package/BUILD-INFO.txt" <<'EOF'
TB371FC Linux 6.12.30 r54 first-membank-iteration reset checkpoint diagnostic
- r53 proved the fault is inside the for_each_mem_range() loop body itself
  (checkpoint before the loop fired; r52's checkpoint after the loop hung)
- r54 moves the SAME single PSCI checkpoint to unconditionally right after
  the __map_memblock() call inside the loop body -- fires after the FIRST
  loop iteration completes, before any second iteration can run
- firing narrows the fault to a LATER memblock region (not the first);
  not firing means the very first memblock region's __map_memblock() call
  itself faults
EOF
( cd "$package"; sha256sum Image config System.map BUILD-INFO.txt >SHA256SUMS; sha256sum -c SHA256SUMS )
stat -c 'Image=%s bytes' "$package/Image"
