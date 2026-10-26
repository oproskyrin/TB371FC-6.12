#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

source_dir=/root/tb371fc/linux-6.12-donor-r64
kernel_dir=/root/tb371fc/linux-6.12-donor-r65
base_out=/root/tb371fc/build-6.12-r64-embedded-pgtable-pool
out_dir=/root/tb371fc/build-6.12-r65-setup-arch-checkpoint
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r65-embedded-pgtable-pool

test -d "$source_dir/.git"
test -f "$base_out/.config"
test ! -e "$kernel_dir" || { echo "Refusing to overwrite $kernel_dir" >&2; exit 1; }
test ! -e "$out_dir" || { echo "Refusing to overwrite $out_dir" >&2; exit 1; }
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }

# r64 is the hardware-proven source: its dedicated 1 MiB Image/BSS page-table
# pool let kexec Linux 6.12 finish paging_init().  r65 makes exactly one
# diagnostic change: remove that checkpoint and place it after setup_arch().
cp -a --reflink=auto "$source_dir" "$kernel_dir"
mkdir -p "$out_dir"
cp "$base_out/.config" "$out_dir/.config"

python3 - \
  "$kernel_dir/arch/arm64/kernel/setup.c" \
  "$kernel_dir/init/main.c" <<'PYEOF'
import sys

setup_path, main_path = sys.argv[1:3]
setup = open(setup_path, encoding='utf-8').read()
main = open(main_path, encoding='utf-8').read()

paging_anchor = '\tpaging_init();\n'
checkpoint_start = '#ifdef CONFIG_TB371FC_POST_MMU_RESET_CHECKPOINT\n'
start = setup.index(paging_anchor) + len(paging_anchor)
assert setup.startswith(checkpoint_start, start), \
    'r64 post-paging_init checkpoint is not at the pinned anchor'
end = setup.index('#endif\n', start) + len('#endif\n')
old_checkpoint = setup[start:end]
assert old_checkpoint.count('movk x0, #0x8400, lsl #16') == 1
assert 'paging_init() returned' in old_checkpoint
setup = setup[:start] + setup[end:]

setup_arch_anchor = '\tsetup_arch(&command_line);\n'
assert main.count(setup_arch_anchor) == 1, 'setup_arch anchor is not unique'
new_checkpoint = '''#ifdef CONFIG_TB371FC_POST_MMU_RESET_CHECKPOINT
\t/* r65: setup_arch() returned with the r64 embedded early page-table
\t * pool still active.  A reset here proves the remainder of arm64
\t * setup_arch() survives the warm kexec handoff. */
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
main = main.replace(setup_arch_anchor, setup_arch_anchor + new_checkpoint)

assert 'movk x0, #0x8400, lsl #16' not in setup
assert main.count('movk x0, #0x8400, lsl #16') == 1
open(setup_path, 'w', encoding='utf-8', newline='\n').write(setup)
open(main_path, 'w', encoding='utf-8', newline='\n').write(main)
PYEOF

"$kernel_dir/scripts/config" --file "$out_dir/.config" \
  --enable TB371FC_POST_MMU_RESET_CHECKPOINT \
  --set-str LOCALVERSION '-tb371fc-r65-setup-arch-checkpoint'
make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 olddefconfig >/dev/null

grep -qx 'CONFIG_TB371FC_EARLY_FB_MARKER=y' "$out_dir/.config"
grep -qx 'CONFIG_TB371FC_LATE_FB_MARKER=y' "$out_dir/.config"
grep -qx 'CONFIG_TB371FC_POST_MMU_RESET_CHECKPOINT=y' "$out_dir/.config"
grep -q 'TB371FC_EARLY_PGTABLE_POOL_PAGES 256' "$kernel_dir/arch/arm64/mm/mmu.c"
grep -q 'return __pa_symbol(page);' "$kernel_dir/arch/arm64/mm/mmu.c"
test "$(grep -c 'movk x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/kernel/setup.c" || true)" = 0
test "$(grep -c 'movk x0, #0x8400, lsl #16' "$kernel_dir/init/main.c")" = 1

make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 -j"$(nproc)" Image

mkdir -p "$package"
install -m0644 "$out_dir/arch/arm64/boot/Image" "$package/Image"
install -m0644 "$out_dir/.config" "$package/config"
install -m0644 "$out_dir/System.map" "$package/System.map"
grep -q ' tb371fc_early_pgtable_pool$' "$package/System.map"
grep -q ' tb371fc_early_pgtable_pool_used$' "$package/System.map"

cat >"$package/BUILD-INFO.txt" <<'EOF'
TB371FC Linux 6.12.30 r65 setup_arch checkpoint

Hardware-proven base retained unchanged:
- r64 dedicated, page-aligned 1 MiB early page-table pool inside the incoming
  Linux Image/BSS;
- V56.6 kexec handoff including the confirmed QCA6390/cnss2 unbind;
- r57 DTB and proven Arch initramfs.

Single diagnostic change:
- remove the PSCI SYSTEM_RESET checkpoint after paging_init();
- place the same single checkpoint immediately after setup_arch() returns in
  start_kernel().

Interpretation:
- automatic reset proves the full arm64 setup_arch() path survives with the
  r64 page-table pool;
- no reset localizes the next fault to the remainder of setup_arch() after
  paging_init(), and requires bounded checkpoints within that interval.

This is a diagnostic candidate, not a release kernel.
EOF

( cd "$package"; sha256sum Image config System.map BUILD-INFO.txt >SHA256SUMS; sha256sum -c SHA256SUMS )
stat -c 'Image=%s bytes' "$package/Image"
