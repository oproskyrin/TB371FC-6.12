#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

source_dir=/root/tb371fc/linux-6.12-donor-r46
kernel_dir=/root/tb371fc/linux-6.12-donor-r47
base_out=/root/tb371fc/build-6.12-r38-watchdog-handoff
out_dir=/root/tb371fc/build-6.12-r47-post-paging-init-checkpoint
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r47-post-paging-init-checkpoint

test -d "$source_dir/.git"
test -f "$base_out/.config"
test ! -e "$kernel_dir" || { echo "Refusing to overwrite $kernel_dir" >&2; exit 1; }
test ! -e "$out_dir" || { echo "Refusing to overwrite $out_dir" >&2; exit 1; }
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }

cp -a --reflink=auto "$source_dir" "$kernel_dir"
mkdir -p "$out_dir" "$package"
cp "$base_out/.config" "$out_dir/.config"

# r46 proved setup_machine_fdt() (this board's 6.12 community device tree
# scan) completes without faulting; the tablet auto-recovered. r47 moves
# the SAME single PSCI checkpoint past jump_label_init(), parse_early_param(),
# dynamic_scs_init(), local_daif_restore(), cpu_uninstall_idmap(),
# xen_early_init(), efi_init() and arm64_memblock_init(), landing right
# after paging_init() returns -- the call that builds the real kernel page
# tables (swapper linear map etc.), replacing the temporary boot idmap. This
# is a classic source of kexec-specific bugs when the incoming kernel's
# memory-layout assumptions differ from the outgoing kernel's, and is tested
# here in isolation from the later, separate unflatten_device_tree() call
# (a full DT unflatten distinct from the lighter setup_machine_fdt() r46
# already proved).
python3 - "$kernel_dir/arch/arm64/kernel/setup.c" <<'PYEOF'
import sys
path = sys.argv[1]
text = open(path, encoding='utf-8').read()

old_post_fdt_checkpoint = (
	"\tsetup_machine_fdt(__fdt_pointer);\n"
	"#ifdef CONFIG_TB371FC_POST_MMU_RESET_CHECKPOINT\n"
	"\t/* Reached: setup_machine_fdt() returned -- this board's 6.12\n"
	"\t * community device tree was scanned/unflattened without\n"
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
	"\ttb371fc_start_kernel_fb_marker(0xffffff00, 23);\n"
	"#endif\n"
)
assert text.count(old_post_fdt_checkpoint) == 1, "r46 post-setup_machine_fdt checkpoint not found or not unique"
reverted = (
	"\tsetup_machine_fdt(__fdt_pointer);\n"
	"#ifdef CONFIG_TB371FC_LATE_FB_MARKER\n"
	"\ttb371fc_start_kernel_fb_marker(0xffffff00, 23);\n"
	"#endif\n"
)
text = text.replace(old_post_fdt_checkpoint, reverted)

needle = (
	"\tpaging_init();\n"
	"#ifdef CONFIG_TB371FC_LATE_FB_MARKER\n"
	"\ttb371fc_start_kernel_fb_marker(0xff8000ff, 30);\n"
	"#endif\n"
)
assert text.count(needle) == 1, "paging_init anchor not found or not unique"
replacement = (
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
text = text.replace(needle, replacement)
open(path, 'w', encoding='utf-8').write(text)
PYEOF

"$kernel_dir/scripts/config" --file "$out_dir/.config" --enable TB371FC_EARLY_FB_MARKER
"$kernel_dir/scripts/config" --file "$out_dir/.config" --enable TB371FC_POST_MMU_RESET_CHECKPOINT
"$kernel_dir/scripts/config" --file "$out_dir/.config" --set-str LOCALVERSION '-tb371fc-r47-post-paging-init-checkpoint'
make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 olddefconfig
grep -qx 'CONFIG_TB371FC_EARLY_FB_MARKER=y' "$out_dir/.config"
grep -qx 'CONFIG_TB371FC_POST_MMU_RESET_CHECKPOINT=y' "$out_dir/.config"
test "$(grep -c 'movk x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/kernel/setup.c")" = "1"
grep -B10 'movk x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/kernel/setup.c" | grep -q 'paging_init() returned' \
	|| { grep -n -B12 'movk x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/kernel/setup.c"; false; }
! grep -q 'movk.*x0, #0x8400, lsl #16' "$kernel_dir/init/main.c"
! grep -q 'movk.*x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/kernel/head.S"

make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 -j"$(nproc)" Image

install -m0644 "$out_dir/arch/arm64/boot/Image" "$package/Image"
install -m0644 "$out_dir/.config" "$package/config"
install -m0644 "$out_dir/System.map" "$package/System.map"
cat >"$package/BUILD-INFO.txt" <<'EOF'
TB371FC Linux 6.12.30 r47 post-paging_init reset checkpoint diagnostic
- r46's post-setup_machine_fdt checkpoint reverted; hardware result
  2026-08-28 proved this board's 6.12 device tree parses without faulting
- single PSCI SYSTEM_RESET checkpoint moved to right after paging_init()
  returns in setup_arch(), past jump_label_init/parse_early_param/
  dynamic_scs_init/local_daif_restore/cpu_uninstall_idmap/xen_early_init/
  efi_init/arm64_memblock_init
- tests whether building the real kernel page tables succeeds under this
  kexec handoff
EOF
( cd "$package"; sha256sum Image config System.map BUILD-INFO.txt >SHA256SUMS; sha256sum -c SHA256SUMS )
stat -c 'Image=%s bytes' "$package/Image"
