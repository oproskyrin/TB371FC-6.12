#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

source_dir=/root/tb371fc/linux-6.12-donor-r47
kernel_dir=/root/tb371fc/linux-6.12-donor-r53
base_out=/root/tb371fc/build-6.12-r38-watchdog-handoff
out_dir=/root/tb371fc/build-6.12-r53-pre-membank-loop-checkpoint
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r53-pre-membank-loop-checkpoint

test -d "$source_dir/.git"
test -f "$base_out/.config"
test ! -e "$kernel_dir" || { echo "Refusing to overwrite $kernel_dir" >&2; exit 1; }
test ! -e "$out_dir" || { echo "Refusing to overwrite $out_dir" >&2; exit 1; }
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }

cp -a --reflink=auto "$source_dir" "$kernel_dir"
mkdir -p "$out_dir" "$package"
cp "$base_out/.config" "$out_dir/.config"

# r52 proved the fault is NOT in the kernel-text remap/kfence-pool tail of
# map_mem() (checkpoint after the for_each_mem_range() membank loop hung).
# r51 proved entry to paging_init()/map_mem() is clean. So the fault is
# somewhere in: arm64_kfence_alloc_pool(), memblock_mark_nomap() on the
# kernel text/rodata range, or the for_each_mem_range() loop itself
# (__map_memblock() per memblock region -- the code path r50's refuted
# reserved-memory DTS hypothesis targeted). r53 splits this range again:
# moves the single PSCI checkpoint to right before the for_each_mem_range()
# loop begins, immediately after memblock_mark_nomap(). Firing narrows the
# fault to inside the loop itself (mapping one of the memory regions,
# plausibly one actively used by live remote-processor firmware under
# kexec); not firing narrows it to arm64_kfence_alloc_pool() or
# memblock_mark_nomap().
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

old_pre_loop = (
	"\tmemblock_mark_nomap(kernel_start, kernel_end - kernel_start);\n"
	"\n"
	"\t/* map all the memory banks */\n"
	"\tfor_each_mem_range(i, &start, &end) {\n"
)
assert text.count(old_pre_loop) == 1, "memblock_mark_nomap + loop entry not found or not unique"
replacement = (
	"\tmemblock_mark_nomap(kernel_start, kernel_end - kernel_start);\n"
	"\n"
	"#ifdef CONFIG_TB371FC_POST_MMU_RESET_CHECKPOINT\n"
	"\t/* Reached: arm64_kfence_alloc_pool() and memblock_mark_nomap()\n"
	"\t * both completed -- about to enter the for_each_mem_range()\n"
	"\t * memory-bank mapping loop. Single PSCI SYSTEM_RESET\n"
	"\t * checkpoint (SMC 0x84000009). */\n"
	"\tasm volatile(\n"
	"\t\t\"mov x1, xzr\\n\"\n"
	"\t\t\"mov x2, xzr\\n\"\n"
	"\t\t\"mov x3, xzr\\n\"\n"
	"\t\t\"mov x0, #0x09\\n\"\n"
	"\t\t\"movk x0, #0x8400, lsl #16\\n\"\n"
	"\t\t\"smc #0\\n\"\n"
	"\t\t::: \"x0\", \"x1\", \"x2\", \"x3\", \"memory\");\n"
	"#endif\n"
	"\n"
	"\t/* map all the memory banks */\n"
	"\tfor_each_mem_range(i, &start, &end) {\n"
)
text = text.replace(old_pre_loop, replacement)
open(path, 'w', encoding='utf-8').write(text)
PYEOF

"$kernel_dir/scripts/config" --file "$out_dir/.config" --enable TB371FC_EARLY_FB_MARKER
"$kernel_dir/scripts/config" --file "$out_dir/.config" --enable TB371FC_POST_MMU_RESET_CHECKPOINT
"$kernel_dir/scripts/config" --file "$out_dir/.config" --set-str LOCALVERSION '-tb371fc-r53-pre-membank-loop-checkpoint'
make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 olddefconfig
grep -qx 'CONFIG_TB371FC_EARLY_FB_MARKER=y' "$out_dir/.config"
grep -qx 'CONFIG_TB371FC_POST_MMU_RESET_CHECKPOINT=y' "$out_dir/.config"
test "$(grep -c 'movk x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/mm/mmu.c")" = "1"
grep -B15 'movk x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/mm/mmu.c" | grep -q 'about to enter the for_each_mem_range' \
	|| { grep -n -B15 'movk x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/mm/mmu.c"; false; }
! grep -q 'movk.*x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/kernel/setup.c"
! grep -q 'movk.*x0, #0x8400, lsl #16' "$kernel_dir/init/main.c"
! grep -q 'movk.*x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/kernel/head.S"

make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 -j"$(nproc)" Image

install -m0644 "$out_dir/arch/arm64/boot/Image" "$package/Image"
install -m0644 "$out_dir/.config" "$package/config"
install -m0644 "$out_dir/System.map" "$package/System.map"
cat >"$package/BUILD-INFO.txt" <<'EOF'
TB371FC Linux 6.12.30 r53 pre-membank-loop reset checkpoint diagnostic
- r51 proved entry to paging_init()/map_mem() is clean (fired)
- r52 proved the checkpoint right after the for_each_mem_range() membank
  loop does NOT fire (hung) -- fault is in kfence_alloc_pool/mark_nomap or
  the loop itself
- r53 moves the SAME single PSCI checkpoint to right before the
  for_each_mem_range() loop begins, immediately after memblock_mark_nomap()
- firing narrows the fault to inside the loop itself (mapping one of the
  memory regions); not firing narrows it to arm64_kfence_alloc_pool() or
  memblock_mark_nomap()
EOF
( cd "$package"; sha256sum Image config System.map BUILD-INFO.txt >SHA256SUMS; sha256sum -c SHA256SUMS )
stat -c 'Image=%s bytes' "$package/Image"
