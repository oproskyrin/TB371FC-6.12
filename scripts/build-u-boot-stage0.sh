#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source_dir=${UBOOT_SOURCE_DIR:-/root/tb371fc-u-boot}
output_dir=${UBOOT_OUTPUT_DIR:-/root/tb371fc-u-boot-out-tb371fc}
artifact_dir=${UBOOT_ARTIFACT_DIR:-/mnt/d/TB371FC-builds/u-boot-tb371fc-stage0}
jobs=${JOBS:-$(nproc)}
device_tree=qcom/sm8250-lenovo-tb371fc-u-boot
source_dts="$source_dir/dts/upstream/src/arm64/qcom/sm8250-lenovo-tb371fc-u-boot.dts"
project_dts="$project_dir/u-boot-port/dts/sm8250-lenovo-tb371fc-u-boot.dts"
fragment="$project_dir/u-boot-port/tb371fc-stage0.config"
project_env="$project_dir/u-boot-port/tb371fc-stage0.env"
source_env="$source_dir/board/qualcomm/tb371fc-stage0.env"
early_probe_patch="$project_dir/u-boot-port/patches/0001-tb371fc-add-early-framebuffer-boundary-probe.patch"

for input in "$source_dir/Makefile" "$project_dts" "$fragment" "$project_env" \
	"$early_probe_patch"; do
	[[ -s $input ]] || { echo "Missing input: $input" >&2; exit 1; }
done

if git -C "$source_dir" apply --reverse --check "$early_probe_patch" \
	>/dev/null 2>&1; then
	echo 'TB371FC early-probe patch already applied.'
else
	git -C "$source_dir" apply --check "$early_probe_patch"
	git -C "$source_dir" apply "$early_probe_patch"
fi

if [[ -e $source_dts ]] && ! cmp -s "$project_dts" "$source_dts"; then
	if git -C "$source_dir" ls-files --error-unmatch \
		"dts/upstream/src/arm64/qcom/$(basename "$source_dts")" >/dev/null 2>&1 ||
		! grep -q 'Minimal U-Boot hardware description for the Lenovo TB371FC' "$source_dts"; then
		echo "Refusing to replace a different U-Boot DTS: $source_dts" >&2
		exit 1
	fi
fi
install -m0644 "$project_dts" "$source_dts"
install -m0644 "$project_env" "$source_env"

rm -rf -- "$output_dir"
make -C "$source_dir" O="$output_dir" qcom_defconfig qcom-phone.config
install -m0644 "$fragment" "$output_dir/tb371fc-stage0.config"
KCONFIG_CONFIG="$output_dir/.config" \
	"$source_dir/scripts/kconfig/merge_config.sh" -m -O "$output_dir" \
	"$output_dir/.config" "$output_dir/tb371fc-stage0.config"
make -C "$source_dir" O="$output_dir" olddefconfig
make -C "$source_dir" O="$output_dir" \
	CROSS_COMPILE=aarch64-linux-gnu- DEVICE_TREE="$device_tree" -j"$jobs"

dtb="$output_dir/u-boot.dtb"
[[ -s $output_dir/u-boot-nodtb.bin && -s $dtb ]] || {
	echo "U-Boot build did not produce the expected files" >&2
	exit 1
}

python3 - "$output_dir/u-boot-nodtb.bin" <<'PY'
import struct
import sys
from pathlib import Path

image = Path(sys.argv[1]).read_bytes()
if len(image) < 64 or image[56:60] != b"ARM\x64":
    raise SystemExit("U-Boot output has no ARM64 Image header")
text_offset, image_size, flags = struct.unpack_from("<QQQ", image, 8)
if text_offset != 0x80000:
    raise SystemExit(f"unexpected U-Boot text_offset: {text_offset:#x}")
if image_size < len(image):
    raise SystemExit(
        f"U-Boot header image_size {image_size:#x} is below file size {len(image):#x}"
    )
if flags != 0xA:
    raise SystemExit(f"unexpected U-Boot ARM64 flags: {flags:#x}")
print(
    f"ARM64 header: text_offset={text_offset:#x} "
    f"image_size={image_size:#x} flags={flags:#x}"
)
PY

[[ $(fdtget -t s "$dtb" / model) == "Lenovo TB371FC U-Boot stage-0" ]]
[[ $(fdtget -t x "$dtb" /chosen/framebuffer@9c000000 width) == b80 ]]
[[ $(fdtget -t x "$dtb" /chosen/framebuffer@9c000000 height) == 730 ]]
[[ $(fdtget -t x "$dtb" /chosen/framebuffer@9c000000 stride) == 2e00 ]]
[[ $(fdtget -t s "$dtb" /soc@0/ufshc@1d84000 status) == disabled ]]

mkdir -p "$artifact_dir"
install -m0644 "$output_dir/u-boot-nodtb.bin" "$artifact_dir/"
install -m0644 "$dtb" "$artifact_dir/sm8250-lenovo-tb371fc-u-boot.dtb"
gzip -n -9 -c "$output_dir/u-boot-nodtb.bin" \
	>"$artifact_dir/u-boot-nodtb.bin.gz"
install -m0644 "$output_dir/.config" "$artifact_dir/u-boot.config"
install -m0644 "$project_env" "$artifact_dir/tb371fc-stage0.env"
{
	aarch64-linux-gnu-objdump -d --disassemble=reset "$output_dir/u-boot"
	aarch64-linux-gnu-objdump -d --disassemble=board_fdt_blob_setup \
		"$output_dir/u-boot"
} >"$artifact_dir/early-probe-disassembly.txt"

{
	printf 'U-Boot source: '
	git -C "$source_dir" rev-parse HEAD
	printf 'Device tree: %s\n' "$device_tree"
	printf 'Build UTC: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
	printf 'Hardware status: OFFLINE ONLY; NOT FLASHED\n'
} >"$artifact_dir/BUILD-INFO.txt"

sha256sum \
	"$artifact_dir/u-boot-nodtb.bin" \
	"$artifact_dir/u-boot-nodtb.bin.gz" \
	"$artifact_dir/sm8250-lenovo-tb371fc-u-boot.dtb" \
	"$artifact_dir/early-probe-disassembly.txt" \
	>"$artifact_dir/SHA256SUMS"

cat "$artifact_dir/BUILD-INFO.txt"
cat "$artifact_dir/SHA256SUMS"
