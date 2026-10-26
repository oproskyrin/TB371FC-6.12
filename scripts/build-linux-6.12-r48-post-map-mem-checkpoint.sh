#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

source_dir=/root/tb371fc/linux-6.12-donor-r47
kernel_dir=/root/tb371fc/linux-6.12-donor-r48
base_out=/root/tb371fc/build-6.12-r38-watchdog-handoff
out_dir=/root/tb371fc/build-6.12-r48-post-map-mem-checkpoint
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r48-post-map-mem-checkpoint

test -d "$source_dir/.git"
test -f "$base_out/.config"
test ! -e "$kernel_dir" || { echo "Refusing to overwrite $kernel_dir" >&2; exit 1; }
test ! -e "$out_dir" || { echo "Refusing to overwrite $out_dir" >&2; exit 1; }
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }

cp -a --reflink=auto "$source_dir" "$kernel_dir"
mkdir -p "$out_dir" "$package"
cp "$base_out/.config" "$out_dir/.config"

# r47 (checkpoint after paging_init() returns) hung with the confirmed
# error-31 signal. paging_init() itself is short:
#   map_mem(swapper_pg_dir); memblock_allow_resize();
#   create_idmap(); declare_kernel_vmas();
# map_mem() builds the full linear map for all of RAM from the current
# memblock regions -- directly dependent on the physical memory layout,
# a strong kexec-specific-bug candidate since those memblock reservations
# reflect what arm64_memblock_init() saw, which can differ from a cold ABL
# boot. r48 places the single PSCI checkpoint right after map_mem() returns,
# isolating it from create_idmap()/declare_kernel_vmas() which run after.
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
assert text.count(old_post_paging_init_checkpoint) == 1, "r47 post-paging_init checkpoint not found or not unique"
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

needle = (
	"void __init paging_init(void)\n"
	"{\n"
	"\tmap_mem(swapper_pg_dir);\n"
	"\n"
	"\tmemblock_allow_resize();\n"
)
assert text.count(needle) == 1, "map_mem anchor not found or not unique"
replacement = (
	"void __init paging_init(void)\n"
	"{\n"
	"\tmap_mem(swapper_pg_dir);\n"
	"#ifdef CONFIG_TB371FC_POST_MMU_RESET_CHECKPOINT\n"
	"\t/* Reached: map_mem() returned -- the full linear map for all\n"
	"\t * of RAM (built from current memblock regions) was created\n"
	"\t * without faulting. Single PSCI SYSTEM_RESET checkpoint (SMC\n"
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
	"\n"
	"\tmemblock_allow_resize();\n"
)
text = text.replace(needle, replacement)
open(path, 'w', encoding='utf-8').write(text)
PYEOF

"$kernel_dir/scripts/config" --file "$out_dir/.config" --enable TB371FC_EARLY_FB_MARKER
"$kernel_dir/scripts/config" --file "$out_dir/.config" --enable TB371FC_POST_MMU_RESET_CHECKPOINT
"$kernel_dir/scripts/config" --file "$out_dir/.config" --set-str LOCALVERSION '-tb371fc-r48-post-map-mem-checkpoint'
make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 olddefconfig
grep -qx 'CONFIG_TB371FC_EARLY_FB_MARKER=y' "$out_dir/.config"
grep -qx 'CONFIG_TB371FC_POST_MMU_RESET_CHECKPOINT=y' "$out_dir/.config"
test "$(grep -c 'movk x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/mm/mmu.c")" = "1"
grep -B10 'movk x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/mm/mmu.c" | grep -q 'map_mem() returned' \
	|| { grep -n -B12 'movk x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/mm/mmu.c"; false; }
! grep -q 'movk.*x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/kernel/setup.c"
! grep -q 'movk.*x0, #0x8400, lsl #16' "$kernel_dir/init/main.c"
! grep -q 'movk.*x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/kernel/head.S"

make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 -j"$(nproc)" Image

install -m0644 "$out_dir/arch/arm64/boot/Image" "$package/Image"
install -m0644 "$out_dir/.config" "$package/config"
install -m0644 "$out_dir/System.map" "$package/System.map"
cat >"$package/BUILD-INFO.txt" <<'EOF'
TB371FC Linux 6.12.30 r48 post-map_mem reset checkpoint diagnostic
- r47's post-paging_init() checkpoint reverted; hardware result 2026-08-28
  narrowed the fault to inside paging_init()
- single PSCI SYSTEM_RESET checkpoint moved to right after map_mem() returns
  in paging_init(), before memblock_allow_resize()/create_idmap()/
  declare_kernel_vmas()
- tests whether building the full RAM linear map succeeds under this kexec
  handoff
EOF
( cd "$package"; sha256sum Image config System.map BUILD-INFO.txt >SHA256SUMS; sha256sum -c SHA256SUMS )
stat -c 'Image=%s bytes' "$package/Image"
