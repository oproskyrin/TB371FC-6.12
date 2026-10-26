#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

source_dir=/root/tb371fc/linux-6.12-donor-r66
kernel_dir=/root/tb371fc/linux-6.12-donor-r67
base_out=/root/tb371fc/build-6.12-r66-xen-checkpoint
out_dir=/root/tb371fc/build-6.12-r67-efi-checkpoint
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r67-embedded-pgtable-pool

test -d "$source_dir/.git"
test -f "$base_out/.config"
test ! -e "$kernel_dir" || { echo "Refusing to overwrite $kernel_dir" >&2; exit 1; }
test ! -e "$out_dir" || { echo "Refusing to overwrite $out_dir" >&2; exit 1; }
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }

# r67 keeps the r64 hardware-proven page-table pool and all r66 code. Its only
# diagnostic change moves the reset checkpoint from after xen_early_init() to
# immediately after efi_init().
cp -a --reflink=auto "$source_dir" "$kernel_dir"
mkdir -p "$out_dir"
cp "$base_out/.config" "$out_dir/.config"

python3 - "$kernel_dir/arch/arm64/kernel/setup.c" <<'PYEOF'
import sys

path = sys.argv[1]
setup = open(path, encoding='utf-8').read()
xen_anchor = '\txen_early_init();\n'
checkpoint_start = '#ifdef CONFIG_TB371FC_POST_MMU_RESET_CHECKPOINT\n'
start = setup.index(xen_anchor) + len(xen_anchor)
assert setup.startswith(checkpoint_start, start), \
    'r66 post-xen checkpoint is not at the pinned anchor'
end = setup.index('#endif\n', start) + len('#endif\n')
old_checkpoint = setup[start:end]
assert old_checkpoint.count('movk x0, #0x8400, lsl #16') == 1
assert 'xen_early_init() returned' in old_checkpoint
setup = setup[:start] + setup[end:]

efi_anchor = '\tefi_init();\n'
assert setup.count(efi_anchor) == 1, 'efi_init anchor is not unique'
new_checkpoint = '''#ifdef CONFIG_TB371FC_POST_MMU_RESET_CHECKPOINT
\t/* r67: efi_init() returned. A reset here separates a failure inside
\t * efi_init() from the remaining architecture setup. */
\tasm volatile(
\t\t"mov x1, xzr\\n"
\t\t"mov x2, xzr\\n"
\t\t"mov x3, xzr\\n"
\t\t"mov x0, #0x09\\n"
\t\t"movk x0, #0x8400, lsl #16\\n"
\t\t"smc #0\\n"
\t\t::: "x0", "x1", "x2", "x3", "memory");
#endif
'''
setup = setup.replace(efi_anchor, efi_anchor + new_checkpoint)

assert setup.count('movk x0, #0x8400, lsl #16') == 1
assert setup.index(xen_anchor) < setup.index(efi_anchor) < setup.index(new_checkpoint)
assert setup.index(new_checkpoint) < setup.index('tb371fc_start_kernel_fb_marker(0xff0080ff, 27);')
open(path, 'w', encoding='utf-8', newline='\n').write(setup)
PYEOF

"$kernel_dir/scripts/config" --file "$out_dir/.config" \
  --enable TB371FC_POST_MMU_RESET_CHECKPOINT \
  --set-str LOCALVERSION '-tb371fc-r67-efi-checkpoint'
make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 olddefconfig >/dev/null

grep -qx 'CONFIG_TB371FC_EARLY_FB_MARKER=y' "$out_dir/.config"
grep -qx 'CONFIG_TB371FC_LATE_FB_MARKER=y' "$out_dir/.config"
grep -qx 'CONFIG_TB371FC_POST_MMU_RESET_CHECKPOINT=y' "$out_dir/.config"
grep -q 'TB371FC_EARLY_PGTABLE_POOL_PAGES 256' "$kernel_dir/arch/arm64/mm/mmu.c"
grep -q 'return __pa_symbol(page);' "$kernel_dir/arch/arm64/mm/mmu.c"
test "$(grep -c 'movk x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/kernel/setup.c")" = 1
test "$(grep -c 'movk x0, #0x8400, lsl #16' "$kernel_dir/init/main.c" || true)" = 0

make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 -j"$(nproc)" Image

mkdir -p "$package"
install -m0644 "$out_dir/arch/arm64/boot/Image" "$package/Image"
install -m0644 "$out_dir/.config" "$package/config"
install -m0644 "$out_dir/System.map" "$package/System.map"
grep -q ' tb371fc_early_pgtable_pool$' "$package/System.map"
grep -q ' tb371fc_early_pgtable_pool_used$' "$package/System.map"

cat >"$package/BUILD-INFO.txt" <<'EOF'
TB371FC Linux 6.12.30 r67 efi_init checkpoint

Hardware-proven base retained unchanged:
- r64 dedicated, page-aligned 1 MiB early page-table pool inside the incoming
  Linux Image/BSS;
- r66 hardware proof that xen_early_init() returns;
- V56.6 handoff with confirmed QCA6390/cnss2 unbind;
- r57 DTB and proven Arch initramfs.

Single diagnostic change from r66:
- remove the checkpoint after xen_early_init();
- place the same single PSCI SYSTEM_RESET checkpoint immediately after
  efi_init().

Interpretation:
- automatic reset proves efi_init() returned;
- no reset with final stage-26 green marker localizes the current
  layout-sensitive stall to efi_init().

This is a diagnostic candidate, not a release kernel.
EOF

( cd "$package"; sha256sum Image config System.map BUILD-INFO.txt >SHA256SUMS; sha256sum -c SHA256SUMS )
stat -c 'Image=%s bytes' "$package/Image"
