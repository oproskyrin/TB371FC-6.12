#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

source_dir=/root/tb371fc/linux-6.12-donor-r44
kernel_dir=/root/tb371fc/linux-6.12-donor-r45
base_out=/root/tb371fc/build-6.12-r38-watchdog-handoff
out_dir=/root/tb371fc/build-6.12-r45-post-setup-arch-checkpoint
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r45-post-setup-arch-checkpoint

test -d "$source_dir/.git"
test -f "$base_out/.config"
test ! -e "$kernel_dir" || { echo "Refusing to overwrite $kernel_dir" >&2; exit 1; }
test ! -e "$out_dir" || { echo "Refusing to overwrite $out_dir" >&2; exit 1; }
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }

cp -a --reflink=auto "$source_dir" "$kernel_dir"
mkdir -p "$out_dir" "$package"
cp "$base_out/.config" "$out_dir/.config"

# r44 proved "bl start_kernel" and start_kernel()'s own prologue succeed
# (checkpoint at its first statement fired, tablet auto-recovered). r45
# moves the SAME checkpoint to right after setup_arch() returns -- the
# first large, architecture-specific subsystem start_kernel() calls, and a
# common source of early-boot regressions in kexec/mainlining efforts on
# other Qualcomm platforms. head.S has no checkpoint (unchanged since r43).
python3 - "$kernel_dir/init/main.c" <<'PYEOF'
import sys
path = sys.argv[1]
text = open(path, encoding='utf-8').read()

old_entry_checkpoint = (
	"#ifdef CONFIG_TB371FC_POST_MMU_RESET_CHECKPOINT\n"
	"\t/* Reached: the \"bl start_kernel\" jump in head.S landed here and\n"
	"\t * this C function's own prologue/entry executed. Single PSCI\n"
	"\t * SYSTEM_RESET checkpoint (SMC 0x84000009), literal first\n"
	"\t * statement in start_kernel(), before any other init runs. */\n"
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
)
assert text.count(old_entry_checkpoint) == 1, "r44 start_kernel-entry checkpoint not found or not unique"
text = text.replace(old_entry_checkpoint, "")

needle = "\tsetup_arch(&command_line);\n\t/* Static keys and static calls are needed by LSMs */\n\tjump_label_init();\n"
assert text.count(needle) == 1, "setup_arch anchor not found or not unique"
replacement = (
	"\tsetup_arch(&command_line);\n"
	"#ifdef CONFIG_TB371FC_POST_MMU_RESET_CHECKPOINT\n"
	"\t/* Reached: setup_arch() returned. Single PSCI SYSTEM_RESET\n"
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
	"\t/* Static keys and static calls are needed by LSMs */\n"
	"\tjump_label_init();\n"
)
text = text.replace(needle, replacement)
open(path, 'w', encoding='utf-8').write(text)
PYEOF

"$kernel_dir/scripts/config" --file "$out_dir/.config" --enable TB371FC_EARLY_FB_MARKER
"$kernel_dir/scripts/config" --file "$out_dir/.config" --enable TB371FC_POST_MMU_RESET_CHECKPOINT
"$kernel_dir/scripts/config" --file "$out_dir/.config" --set-str LOCALVERSION '-tb371fc-r45-post-setup-arch-checkpoint'
make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 olddefconfig
grep -qx 'CONFIG_TB371FC_EARLY_FB_MARKER=y' "$out_dir/.config"
grep -qx 'CONFIG_TB371FC_POST_MMU_RESET_CHECKPOINT=y' "$out_dir/.config"
test "$(grep -c 'movk x0, #0x8400, lsl #16' "$kernel_dir/init/main.c")" = "1"
grep -B10 'movk x0, #0x8400, lsl #16' "$kernel_dir/init/main.c" | grep -q 'setup_arch() returned' \
	|| { grep -n -B12 'movk x0, #0x8400, lsl #16' "$kernel_dir/init/main.c"; false; }
! grep -q 'movk.*x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/kernel/head.S"

make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 -j"$(nproc)" Image

install -m0644 "$out_dir/arch/arm64/boot/Image" "$package/Image"
install -m0644 "$out_dir/.config" "$package/config"
install -m0644 "$out_dir/System.map" "$package/System.map"
cat >"$package/BUILD-INFO.txt" <<'EOF'
TB371FC Linux 6.12.30 r45 post-setup_arch() reset checkpoint diagnostic
- r44's start_kernel()-entry checkpoint reverted; hardware result 2026-08-28
  proved start_kernel() entry/prologue completes and returns to V56.6
  unattended
- single PSCI SYSTEM_RESET checkpoint moved to right after setup_arch()
  returns in start_kernel()
- head.S unchanged since r43 (no checkpoint there)
EOF
( cd "$package"; sha256sum Image config System.map BUILD-INFO.txt >SHA256SUMS; sha256sum -c SHA256SUMS )
stat -c 'Image=%s bytes' "$package/Image"
