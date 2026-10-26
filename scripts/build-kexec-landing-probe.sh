#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
output_dir=${OUTPUT_DIR:-/mnt/d/TB371FC-builds/kexec-landing-probe-v1}
source="$project_dir/u-boot-port/kexec-landing-probe.S"
linker="$project_dir/u-boot-port/kexec-landing-probe.lds"
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT

for input in "$source" "$linker"; do
	[[ -s $input ]] || { echo "Missing input: $input" >&2; exit 1; }
done
[[ ! -e $output_dir ]] || {
	echo "Refusing to overwrite existing output: $output_dir" >&2
	exit 1
}
mkdir -p "$output_dir"

aarch64-linux-gnu-gcc -c -x assembler-with-cpp -nostdlib -ffreestanding \
	-o "$stage/kexec-landing-probe.o" "$source"
aarch64-linux-gnu-ld -nostdlib -static -T "$linker" \
	-o "$output_dir/kexec-landing-probe.elf" \
	"$stage/kexec-landing-probe.o"
aarch64-linux-gnu-objcopy -O binary --gap-fill 0 --pad-to 0x1000 \
	"$output_dir/kexec-landing-probe.elf" \
	"$output_dir/kexec-landing-probe.bin"

[[ $(stat -c %s "$output_dir/kexec-landing-probe.bin") -eq 4096 ]]
[[ $(dd if="$output_dir/kexec-landing-probe.bin" bs=1 skip=56 count=4 \
	2>/dev/null | od -An -tx1 | tr -d ' \n') == 41524d64 ]]
[[ $(od -An -tx8 -j8 -N8 "$output_dir/kexec-landing-probe.bin" | \
	tr -d ' \n') == 0000000000080000 ]]
[[ $(od -An -tx8 -j16 -N8 "$output_dir/kexec-landing-probe.bin" | \
	tr -d ' \n') == 0000000000001000 ]]

aarch64-linux-gnu-objdump -d "$output_dir/kexec-landing-probe.elf" \
	>"$output_dir/kexec-landing-probe.disassembly.txt"
cat >"$output_dir/TEST-CONTRACT.txt" <<'EOF'
Expected entry proof:
  full-screen, wide opaque red/blue horizontal bands for about eight seconds.

After the dwell the probe issues PSCI SYSTEM_RESET via SMC. It contains no
Linux code, stack, DT parser, USB, storage or display driver. A visible pattern
therefore proves that the old kernel, relocation code, kexec purgatory and the
final ARM64 branch all completed.
EOF
sha256sum "$output_dir/kexec-landing-probe.bin" \
	"$output_dir/kexec-landing-probe.elf" \
	>"$output_dir/SHA256SUMS"
cat "$output_dir/SHA256SUMS"

