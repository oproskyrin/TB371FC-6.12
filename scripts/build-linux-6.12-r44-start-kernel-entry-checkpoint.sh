#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

source_dir=/root/tb371fc/linux-6.12-donor-r43
kernel_dir=/root/tb371fc/linux-6.12-donor-r44
base_out=/root/tb371fc/build-6.12-r38-watchdog-handoff
out_dir=/root/tb371fc/build-6.12-r44-start-kernel-entry-checkpoint
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r44-start-kernel-entry-checkpoint

test -d "$source_dir/.git"
test -f "$base_out/.config"
test ! -e "$kernel_dir" || { echo "Refusing to overwrite $kernel_dir" >&2; exit 1; }
test ! -e "$out_dir" || { echo "Refusing to overwrite $out_dir" >&2; exit 1; }
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }

cp -a --reflink=auto "$source_dir" "$kernel_dir"
mkdir -p "$out_dir" "$package"
cp "$base_out/.config" "$out_dir/.config"

# r43 (no checkpoint at all) hung with no visible signal past the head.S
# stage-74 marker and no automatic recovery; the serial-over-USB link itself
# degraded to a genuine device error, not the usual Windows-side port race.
# r42 already proved the entire head.S assembly path is clean, so the fault
# is somewhere between "bl start_kernel" and wherever r43 actually stopped
# making progress. r44 places the SAME single PSCI SYSTEM_RESET checkpoint
# as the literal first statement inside start_kernel() in init/main.c
# (before set_task_stack_end_magic and the pre-existing but disabled
# TB371FC_START_MARKER chain), isolating whether the "bl start_kernel" jump
# and the C function's own entry/prologue succeed. head.S itself is left
# exactly as r43 (no checkpoint there).
python3 - "$kernel_dir/init/main.c" <<'PYEOF'
import sys
path = sys.argv[1]
text = open(path, encoding='utf-8').read()

needle = (
	"void start_kernel(void)\n"
	"{\n"
	"\tchar *command_line;\n"
	"\tchar *after_dashes;\n"
	"\n"
	"\tTB371FC_START_MARKER(0xff800000, 14);\n"
)
assert text.count(needle) == 1, "start_kernel entry anchor not found or not unique"
replacement = (
	"void start_kernel(void)\n"
	"{\n"
	"\tchar *command_line;\n"
	"\tchar *after_dashes;\n"
	"\n"
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
	"\tTB371FC_START_MARKER(0xff800000, 14);\n"
)
text = text.replace(needle, replacement)
open(path, 'w', encoding='utf-8').write(text)
PYEOF

"$kernel_dir/scripts/config" --file "$out_dir/.config" --enable TB371FC_EARLY_FB_MARKER
"$kernel_dir/scripts/config" --file "$out_dir/.config" --enable TB371FC_POST_MMU_RESET_CHECKPOINT
"$kernel_dir/scripts/config" --file "$out_dir/.config" --set-str LOCALVERSION '-tb371fc-r44-start-kernel-entry-checkpoint'
make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 olddefconfig
grep -qx 'CONFIG_TB371FC_EARLY_FB_MARKER=y' "$out_dir/.config"
grep -qx 'CONFIG_TB371FC_POST_MMU_RESET_CHECKPOINT=y' "$out_dir/.config"
grep -q 'movk x0, #0x8400, lsl #16' "$kernel_dir/init/main.c"
# head.S must have no checkpoint of its own (matches r43).
! grep -q 'movk.*x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/kernel/head.S"

make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 -j"$(nproc)" Image

install -m0644 "$out_dir/arch/arm64/boot/Image" "$package/Image"
install -m0644 "$out_dir/.config" "$package/config"
install -m0644 "$out_dir/System.map" "$package/System.map"
cat >"$package/BUILD-INFO.txt" <<'EOF'
TB371FC Linux 6.12.30 r44 start_kernel-entry reset checkpoint diagnostic
- head.S identical to r43 (no checkpoint there; entire assembly path
  already proven clean by r42)
- single PSCI SYSTEM_RESET checkpoint moved into init/main.c as the literal
  first statement inside start_kernel(), before set_task_stack_end_magic
  and the pre-existing (still disabled) TB371FC_START_MARKER framebuffer
  chain
- firing proves the "bl start_kernel" jump and this C function's own
  prologue succeed; not firing narrows the fault to that jump/prologue
  itself
EOF
( cd "$package"; sha256sum Image config System.map BUILD-INFO.txt >SHA256SUMS; sha256sum -c SHA256SUMS )
stat -c 'Image=%s bytes' "$package/Image"
