#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

source_dir=/root/tb371fc/linux-6.12-donor-r65
kernel_dir=/root/tb371fc/linux-6.12-donor-r66
base_out=/root/tb371fc/build-6.12-r65-setup-arch-checkpoint
out_dir=/root/tb371fc/build-6.12-r66-xen-checkpoint
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r66-embedded-pgtable-pool

test -d "$source_dir/.git"
test -f "$base_out/.config"
test ! -e "$kernel_dir" || { echo "Refusing to overwrite $kernel_dir" >&2; exit 1; }
test ! -e "$out_dir" || { echo "Refusing to overwrite $out_dir" >&2; exit 1; }
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }

# r66 keeps the r64 hardware-proven 1 MiB Image/BSS page-table pool. Its only
# diagnostic change from r65 is moving the reset checkpoint from start_kernel()
# to immediately after xen_early_init() and before efi_init().
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

setup_arch_anchor = '\tsetup_arch(&command_line);\n'
checkpoint_start = '#ifdef CONFIG_TB371FC_POST_MMU_RESET_CHECKPOINT\n'
start = main.index(setup_arch_anchor) + len(setup_arch_anchor)
assert main.startswith(checkpoint_start, start), \
    'r65 post-setup_arch checkpoint is not at the pinned anchor'
end = main.index('#endif\n', start) + len('#endif\n')
old_checkpoint = main[start:end]
assert old_checkpoint.count('movk x0, #0x8400, lsl #16') == 1
assert 'setup_arch() returned' in old_checkpoint
main = main[:start] + main[end:]

xen_anchor = '\txen_early_init();\n'
assert setup.count(xen_anchor) == 1, 'xen_early_init anchor is not unique'
new_checkpoint = '''#ifdef CONFIG_TB371FC_POST_MMU_RESET_CHECKPOINT
\t/* r66: xen_early_init() returned. A reset here separates a failure
\t * inside xen_early_init() from efi_init() and subsequent setup. */
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
setup = setup.replace(xen_anchor, xen_anchor + new_checkpoint)

assert main.count('movk x0, #0x8400, lsl #16') == 0
assert setup.count('movk x0, #0x8400, lsl #16') == 1
assert setup.index(xen_anchor) < setup.index(new_checkpoint) < setup.index('\tefi_init();\n')
open(setup_path, 'w', encoding='utf-8', newline='\n').write(setup)
open(main_path, 'w', encoding='utf-8', newline='\n').write(main)
PYEOF

"$kernel_dir/scripts/config" --file "$out_dir/.config" \
  --enable TB371FC_POST_MMU_RESET_CHECKPOINT \
  --set-str LOCALVERSION '-tb371fc-r66-xen-checkpoint'
make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 olddefconfig >/dev/null

grep -qx 'CONFIG_TB371FC_EARLY_FB_MARKER=y' "$out_dir/.config"
grep -qx 'CONFIG_TB371FC_LATE_FB_MARKER=y' "$out_dir/.config"
grep -qx 'CONFIG_TB371FC_POST_MMU_RESET_CHECKPOINT=y' "$out_dir/.config"
grep -q 'TB371FC_EARLY_PGTABLE_POOL_PAGES 256' "$kernel_dir/arch/arm64/mm/mmu.c"
grep -q 'return __pa_symbol(page);' "$kernel_dir/arch/arm64/mm/mmu.c"
test "$(grep -c 'movk x0, #0x8400, lsl #16' "$kernel_dir/init/main.c" || true)" = 0
test "$(grep -c 'movk x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/kernel/setup.c")" = 1

make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 -j"$(nproc)" Image

mkdir -p "$package"
install -m0644 "$out_dir/arch/arm64/boot/Image" "$package/Image"
install -m0644 "$out_dir/.config" "$package/config"
install -m0644 "$out_dir/System.map" "$package/System.map"
grep -q ' tb371fc_early_pgtable_pool$' "$package/System.map"
grep -q ' tb371fc_early_pgtable_pool_used$' "$package/System.map"

cat >"$package/BUILD-INFO.txt" <<'EOF'
TB371FC Linux 6.12.30 r66 xen_early_init checkpoint

Hardware-proven base retained unchanged:
- r64 dedicated, page-aligned 1 MiB early page-table pool inside the incoming
  Linux Image/BSS;
- V56.6 kexec handoff including the confirmed QCA6390/cnss2 unbind;
- r57 DTB and proven Arch initramfs.

Single diagnostic change from r65:
- remove the checkpoint after setup_arch() returns;
- place the same single PSCI SYSTEM_RESET checkpoint immediately after
  xen_early_init() and before efi_init().

Interpretation:
- automatic reset proves xen_early_init() returned and localizes the r65 stall
  to efi_init() or later code;
- no reset with final stage-26 green marker localizes the stall to
  xen_early_init() or entry into it.

This is a diagnostic candidate, not a release kernel.
EOF

( cd "$package"; sha256sum Image config System.map BUILD-INFO.txt >SHA256SUMS; sha256sum -c SHA256SUMS )
stat -c 'Image=%s bytes' "$package/Image"
