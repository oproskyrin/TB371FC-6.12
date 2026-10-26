#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

source_dir=/root/tb371fc/linux-6.12-donor-r47
kernel_dir=/root/tb371fc/linux-6.12-donor-r52
base_out=/root/tb371fc/build-6.12-r38-watchdog-handoff
out_dir=/root/tb371fc/build-6.12-r52-post-membank-loop-checkpoint
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r52-post-membank-loop-checkpoint

test -d "$source_dir/.git"
test -f "$base_out/.config"
test ! -e "$kernel_dir" || { echo "Refusing to overwrite $kernel_dir" >&2; exit 1; }
test ! -e "$out_dir" || { echo "Refusing to overwrite $out_dir" >&2; exit 1; }
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }

cp -a --reflink=auto "$source_dir" "$kernel_dir"
mkdir -p "$out_dir" "$package"
cp "$base_out/.config" "$out_dir/.config"

# r51 proved the fault is genuinely inside paging_init()/map_mem() (checkpoint
# at entry to paging_init(), before map_mem() runs, fired and the tablet
# auto-recovered). map_mem() itself (arch/arm64/mm/mmu.c) does, in order:
#   1. arm64_kfence_alloc_pool()
#   2. memblock_mark_nomap() on the kernel text/rodata range
#   3. for_each_mem_range() loop: __map_memblock() for every memblock region
#      (this maps ALL of system RAM into the linear map, including any
#      physical regions actively used by already-running remote-processor
#      firmware under a live kexec handoff -- the r50 hypothesis, refuted
#      only as a *fix* via extra reserved-memory DTS nodes, not as a
#      location)
#   4. a second __map_memblock() specifically for the kernel text/rodata
#      range, then memblock_clear_nomap()
#   5. arm64_kfence_map_pool()
# r52 splits map_mem() in half: the single PSCI checkpoint moves to right
# after the for_each_mem_range() memory-bank mapping loop completes, before
# the kernel-text-specific remap. Firing narrows the fault to steps 4-5;
# not firing narrows it to steps 1-3 (most likely the memory-bank loop
# itself, given r50's DTS-reservation theory targeted exactly this step
# even though the specific fix tried did not resolve it).
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

old_loop = (
	"\t/* map all the memory banks */\n"
	"\tfor_each_mem_range(i, &start, &end) {\n"
	"\t\tif (start >= end)\n"
	"\t\t\tbreak;\n"
	"\t\t/*\n"
	"\t\t * The linear map must allow allocation tags reading/writing\n"
	"\t\t * if MTE is present. Otherwise, it has the same attributes as\n"
	"\t\t * PAGE_KERNEL.\n"
	"\t\t */\n"
	"\t\t__map_memblock(pgdp, start, end, pgprot_tagged(PAGE_KERNEL),\n"
	"\t\t\t       flags);\n"
	"\t}\n"
)
assert text.count(old_loop) == 1, "for_each_mem_range membank loop not found or not unique"
replacement = old_loop + (
	"#ifdef CONFIG_TB371FC_POST_MMU_RESET_CHECKPOINT\n"
	"\t/* Reached: the for_each_mem_range() loop above completed --\n"
	"\t * every memblock region (all of system RAM, including any\n"
	"\t * physical regions a live remote-processor firmware may be\n"
	"\t * using under kexec) was mapped into the linear map without\n"
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
)
text = text.replace(old_loop, replacement)
open(path, 'w', encoding='utf-8').write(text)
PYEOF

"$kernel_dir/scripts/config" --file "$out_dir/.config" --enable TB371FC_EARLY_FB_MARKER
"$kernel_dir/scripts/config" --file "$out_dir/.config" --enable TB371FC_POST_MMU_RESET_CHECKPOINT
"$kernel_dir/scripts/config" --file "$out_dir/.config" --set-str LOCALVERSION '-tb371fc-r52-post-membank-loop-checkpoint'
make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 olddefconfig
grep -qx 'CONFIG_TB371FC_EARLY_FB_MARKER=y' "$out_dir/.config"
grep -qx 'CONFIG_TB371FC_POST_MMU_RESET_CHECKPOINT=y' "$out_dir/.config"
test "$(grep -c 'movk x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/mm/mmu.c")" = "1"
grep -B15 'movk x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/mm/mmu.c" | grep -q 'for_each_mem_range() loop above completed' \
	|| { grep -n -B15 'movk x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/mm/mmu.c"; false; }
! grep -q 'movk.*x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/kernel/setup.c"
! grep -q 'movk.*x0, #0x8400, lsl #16' "$kernel_dir/init/main.c"
! grep -q 'movk.*x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/kernel/head.S"

make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 -j"$(nproc)" Image

install -m0644 "$out_dir/arch/arm64/boot/Image" "$package/Image"
install -m0644 "$out_dir/.config" "$package/config"
install -m0644 "$out_dir/System.map" "$package/System.map"
cat >"$package/BUILD-INFO.txt" <<'EOF'
TB371FC Linux 6.12.30 r52 post-membank-loop reset checkpoint diagnostic
- r51 proved the fault is inside paging_init()/map_mem() (checkpoint at
  entry fired, auto-recovered)
- r52 moves the SAME single PSCI checkpoint to right after the
  for_each_mem_range() memory-bank mapping loop inside map_mem() completes,
  before the kernel-text-specific remap and arm64_kfence_map_pool()
- firing narrows the fault to the kernel-text remap/kfence-pool tail of
  map_mem(); not firing narrows it to the memory-bank mapping loop itself
  (arm64_kfence_alloc_pool/memblock_mark_nomap/__map_memblock per region)
EOF
( cd "$package"; sha256sum Image config System.map BUILD-INFO.txt >SHA256SUMS; sha256sum -c SHA256SUMS )
stat -c 'Image=%s bytes' "$package/Image"
