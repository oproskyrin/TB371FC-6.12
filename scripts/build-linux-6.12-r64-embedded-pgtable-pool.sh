#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

source_dir=/root/tb371fc/linux-6.12-donor-r60
kernel_dir=/root/tb371fc/linux-6.12-donor-r64
base_out=/root/tb371fc/build-6.12-r60-bargraph-address-indicator
out_dir=/root/tb371fc/build-6.12-r64-embedded-pgtable-pool
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r64-embedded-pgtable-pool

test -d "$source_dir/.git"
test -f "$base_out/.config"
test ! -e "$kernel_dir" || { echo "Refusing to overwrite $kernel_dir" >&2; exit 1; }
test ! -e "$out_dir" || { echo "Refusing to overwrite $out_dir" >&2; exit 1; }
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }

cp -a --reflink=auto "$source_dir" "$kernel_dir"
mkdir -p "$out_dir"
cp "$base_out/.config" "$out_dir/.config"

# Live V56.6 evidence collected on 2026-08-29:
#   * the first incoming 6.12 System RAM bank is 0x80600000-0x806fffff;
#   * all 256 pages in that bank report KPF_SLAB (0x80) in the outgoing
#     4.19 kernel and a zero userspace mapcount;
#   * the outgoing Qualcomm SMMUs use non-coherent table walks;
#   * at least WLAN was proven to remain ONLINE without an explicit unbind.
#
# The first __map_memblock() call allocates persistent page-table pages with
# early_pgtable_alloc().  A stale DMA writer can therefore corrupt the new
# page tables while they are being cleared/populated, even though merely
# mapping the target RAM does not read that RAM.  r64 removes ordinary old-
# kernel RAM allocation from this equation: it uses a page-aligned 1 MiB pool
# inside the incoming kernel's own BSS/Image.  Those pages are relocated with
# the new Image, are already covered by the kernel image reservation, and
# remain resident because they back the permanent linear map.
python3 - "$kernel_dir/arch/arm64/mm/mmu.c" <<'PYEOF'
import sys

path = sys.argv[1]
text = open(path, encoding='utf-8').read()
old = '''static phys_addr_t __init early_pgtable_alloc(int shift)
{
\tphys_addr_t phys;

\tphys = memblock_phys_alloc_range(PAGE_SIZE, PAGE_SIZE, 0,
\t\t\t\t\t MEMBLOCK_ALLOC_NOLEAKTRACE);
\tif (!phys)
\t\tpanic("Failed to allocate page table page\\n");

\treturn phys;
}
'''
new = '''#define TB371FC_EARLY_PGTABLE_POOL_PAGES 256

static u8 tb371fc_early_pgtable_pool
\t[TB371FC_EARLY_PGTABLE_POOL_PAGES * PAGE_SIZE] __aligned(PAGE_SIZE);
static unsigned int tb371fc_early_pgtable_pool_used;

static phys_addr_t __init early_pgtable_alloc(int shift)
{
\tvoid *page;

\tif (tb371fc_early_pgtable_pool_used >=
\t    TB371FC_EARLY_PGTABLE_POOL_PAGES)
\t\tpanic("TB371FC embedded early page-table pool exhausted\\n");

\tpage = tb371fc_early_pgtable_pool +
\t       tb371fc_early_pgtable_pool_used++ * PAGE_SIZE;
\treturn __pa_symbol(page);
}
'''
assert text.count(old) == 1, "early_pgtable_alloc anchor not found or not unique"
text = text.replace(old, new)
open(path, 'w', encoding='utf-8').write(text)
PYEOF

"$kernel_dir/scripts/config" --file "$out_dir/.config" \
  --enable TB371FC_POST_MMU_RESET_CHECKPOINT \
  --set-str LOCALVERSION '-tb371fc-r64-embedded-pgtable-pool'
make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 olddefconfig >/dev/null

grep -qx 'CONFIG_TB371FC_EARLY_FB_MARKER=y' "$out_dir/.config"
grep -qx 'CONFIG_TB371FC_LATE_FB_MARKER=y' "$out_dir/.config"
grep -qx 'CONFIG_TB371FC_POST_MMU_RESET_CHECKPOINT=y' "$out_dir/.config"
grep -q 'TB371FC_EARLY_PGTABLE_POOL_PAGES 256' "$kernel_dir/arch/arm64/mm/mmu.c"
grep -q 'return __pa_symbol(page);' "$kernel_dir/arch/arm64/mm/mmu.c"
test "$(grep -c 'movk x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/kernel/setup.c")" = 1

make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 -j"$(nproc)" Image

mkdir -p "$package"
install -m0644 "$out_dir/arch/arm64/boot/Image" "$package/Image"
install -m0644 "$out_dir/.config" "$package/config"
install -m0644 "$out_dir/System.map" "$package/System.map"
grep -q ' tb371fc_early_pgtable_pool$' "$package/System.map"
grep -q ' tb371fc_early_pgtable_pool_used$' "$package/System.map"

cat >"$package/BUILD-INFO.txt" <<'EOF'
TB371FC Linux 6.12.30 r64 embedded early page-table pool candidate fix

Evidence behind this single change:
- identical Linux 6.12 Image/DTB passes paging_init() on cold ABL boot;
- kexec from V56.6 hangs inside the first __map_memblock() call;
- live /proc/iomem identifies that first bank as 0x80600000-0x806fffff;
- live /proc/kpageflags reports KPF_SLAB (0x80) for all 256 outgoing-4.19
  pages in that bank;
- Qualcomm Apps/GPU SMMUs report non-coherent table walks, and incomplete
  device shutdown was independently proven (WLAN remained ONLINE).

Change:
- early_pgtable_alloc() uses a dedicated, page-aligned 1 MiB pool inside
  the incoming kernel Image/BSS instead of allocating from ordinary RAM
  that held live outgoing-kernel slab/DMA state;
- enables the existing post-paging_init PSCI SYSTEM_RESET checkpoint.

Expected hardware result:
- success: paging_init() returns and the tablet immediately warm-resets to
  the V56.6 control environment;
- failure: the display remains at the pre-map diagnostic and a physical
  power cycle is required.

This is a diagnostic candidate, not a release kernel.
EOF

( cd "$package"; sha256sum Image config System.map BUILD-INFO.txt >SHA256SUMS; sha256sum -c SHA256SUMS )
stat -c 'Image=%s bytes' "$package/Image"
