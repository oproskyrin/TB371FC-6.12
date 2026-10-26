#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

source_dir=/root/tb371fc/linux-6.12-donor-r68
kernel_dir=/root/tb371fc/linux-6.12-donor-r69
base_out=/root/tb371fc/build-6.12-r68-memblock-checkpoint
out_dir=/root/tb371fc/build-6.12-r69-full-boot-no-checkpoint
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r69-full-boot-no-checkpoint

test -d "$source_dir/.git"
test -f "$base_out/.config"
test ! -e "$kernel_dir" || { echo "Refusing to overwrite $kernel_dir" >&2; exit 1; }
test ! -e "$out_dir" || { echo "Refusing to overwrite $out_dir" >&2; exit 1; }
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }

cp -a --reflink=auto "$source_dir" "$kernel_dir"
mkdir -p "$out_dir"
cp "$base_out/.config" "$out_dir/.config"

# r64's embedded early page-table pool (a 256-page/1MiB static array inside
# the incoming 6.12 kernel's own Image/BSS, used by early_pgtable_alloc()
# instead of memblock_phys_alloc()) is hardware-confirmed to let a PSCI
# checkpoint fire cleanly right after paging_init() returns (r64) AND right
# after arm64_memblock_init(), immediately before paging_init() (r68) --
# bounding paging_init()/map_mem() itself, the site of the original hang,
# on both sides. r65/r66/r67 also confirmed setup_arch()/xen_early_init()/
# efi_init() all clean. r69 removes the diagnostic PSCI checkpoint entirely
# (keeping the page-table pool and everything else) to test whether Linux
# 6.12 now reaches a full, sustained boot under a live kexec handoff.
python3 - "$kernel_dir/arch/arm64/kernel/setup.c" <<'PYEOF'
import sys
path = sys.argv[1]
text = open(path, encoding='utf-8').read()

old = (
	"\tarm64_memblock_init();\n"
	"#ifdef CONFIG_TB371FC_POST_MMU_RESET_CHECKPOINT\n"
	"\t/* r68: arm64_memblock_init() returned. Keep this before paging_init()\n"
	"\t * to isolate the next substantial setup_arch() block. */\n"
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
	"\ttb371fc_start_kernel_fb_marker(0xffff8000, 28);\n"
	"\ttb371fc_start_kernel_fb_marker(0xffffff00, 29);\n"
	"#endif\n"
)
assert text.count(old) == 1, "r68 post-arm64_memblock_init checkpoint not found or not unique"
reverted = (
	"\tarm64_memblock_init();\n"
	"#ifdef CONFIG_TB371FC_LATE_FB_MARKER\n"
	"\ttb371fc_start_kernel_fb_marker(0xffff8000, 28);\n"
	"\ttb371fc_start_kernel_fb_marker(0xffffff00, 29);\n"
	"#endif\n"
)
text = text.replace(old, reverted)
open(path, 'w', encoding='utf-8').write(text)
PYEOF

"$kernel_dir/scripts/config" --file "$out_dir/.config" --enable TB371FC_EARLY_FB_MARKER
"$kernel_dir/scripts/config" --file "$out_dir/.config" --disable TB371FC_POST_MMU_RESET_CHECKPOINT
"$kernel_dir/scripts/config" --file "$out_dir/.config" --set-str LOCALVERSION '-tb371fc-r69-full-boot-no-checkpoint'
make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 olddefconfig
grep -qx 'CONFIG_TB371FC_EARLY_FB_MARKER=y' "$out_dir/.config"
! grep -qx 'CONFIG_TB371FC_POST_MMU_RESET_CHECKPOINT=y' "$out_dir/.config"
! grep -q 'movk.*x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/kernel/setup.c"
! grep -q 'movk.*x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/mm/mmu.c"
! grep -q 'movk.*x0, #0x8400, lsl #16' "$kernel_dir/init/main.c"
! grep -q 'movk.*x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/kernel/head.S"
grep -q 'tb371fc_early_pgtable_pool' "$kernel_dir/arch/arm64/mm/mmu.c"

make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 -j"$(nproc)" Image

mkdir -p "$package"
install -m0644 "$out_dir/arch/arm64/boot/Image" "$package/Image"
install -m0644 "$out_dir/.config" "$package/config"
install -m0644 "$out_dir/System.map" "$package/System.map"
cat >"$package/BUILD-INFO.txt" <<'EOF'
TB371FC Linux 6.12.30 r69 full-boot test, no diagnostic checkpoint
- keeps r64's embedded early page-table pool (256-page/1MiB static array
  in the kernel's own Image/BSS, used by early_pgtable_alloc() instead of
  memblock_phys_alloc()) -- hardware-confirmed to let checkpoints fire
  cleanly on both sides of paging_init()/map_mem() (r64, r68) plus
  setup_arch()/xen_early_init()/efi_init() (r65-r67)
- removes the diagnostic PSCI reset checkpoint entirely
- tests whether Linux 6.12 now reaches a full, sustained boot (Arch/KDE)
  under a live kexec handoff from V56.6, with WLAN cleanly unbound first
EOF
( cd "$package"; sha256sum Image config System.map BUILD-INFO.txt >SHA256SUMS; sha256sum -c SHA256SUMS )
stat -c 'Image=%s bytes' "$package/Image"
