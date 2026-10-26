#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

artifact_dir=${1:-/mnt/d/TB371FC-builds/u-boot-tb371fc-stage0}
dtb="$artifact_dir/sm8250-lenovo-tb371fc-u-boot.dtb"

for input in \
	"$artifact_dir/u-boot-nodtb.bin" \
	"$artifact_dir/u-boot-nodtb.bin.gz" \
	"$dtb" \
	"$artifact_dir/u-boot.config" \
	"$artifact_dir/tb371fc-stage0.env" \
	"$artifact_dir/early-probe-disassembly.txt" \
	"$artifact_dir/BUILD-INFO.txt" \
	"$artifact_dir/SHA256SUMS"; do
	[[ -s $input ]] || { echo "Missing artifact: $input" >&2; exit 1; }
done

(cd "$artifact_dir" && sha256sum -c SHA256SUMS)
gzip -t "$artifact_dir/u-boot-nodtb.bin.gz"

[[ $(fdtget -t s "$dtb" / model) == "Lenovo TB371FC U-Boot stage-0" ]]
[[ $(fdtget -t s "$dtb" /chosen/framebuffer@9c000000 compatible) == simple-framebuffer ]]
[[ $(fdtget -t x "$dtb" /chosen/framebuffer@9c000000 width) == b80 ]]
[[ $(fdtget -t x "$dtb" /chosen/framebuffer@9c000000 height) == 730 ]]
[[ $(fdtget -t x "$dtb" /chosen/framebuffer@9c000000 stride) == 2e00 ]]
[[ $(fdtget -t s "$dtb" /chosen/framebuffer@9c000000 format) == a8r8g8b8 ]]
[[ $(fdtget -t s "$dtb" /soc@0/ufshc@1d84000 status) == disabled ]]
[[ $(fdtget -t s "$dtb" /soc@0/usb@a6f8800 status) == okay ]]
[[ $(fdtget -t s "$dtb" /soc@0/usb@a8f8800 status) == disabled ]]

if grep -Eq '^CONFIG_UFS(_QCOM)?=(y|m)$' "$artifact_dir/u-boot.config"; then
	echo 'UFS storage support is unexpectedly enabled.' >&2
	exit 1
fi
grep -q '^# CONFIG_FASTBOOT_FLASH is not set$' "$artifact_dir/u-boot.config"
grep -q '^CONFIG_VIDEO_SIMPLE=y$' "$artifact_dir/u-boot.config"
grep -q '^CONFIG_TEXT_BASE=0x80080000$' "$artifact_dir/u-boot.config"
grep -q '^CONFIG_TB371FC_STAGE0_EARLY_PROBE=y$' "$artifact_dir/u-boot.config"
grep -q '<reset>:' "$artifact_dir/early-probe-disassembly.txt"
grep -q 'movk.*x9, #0x9c00' "$artifact_dir/early-probe-disassembly.txt"
grep -q 'stp.*x10, x10' "$artifact_dir/early-probe-disassembly.txt"
grep -q '<board_fdt_blob_setup>:' "$artifact_dir/early-probe-disassembly.txt"
grep -q 'mov.*x0, #0x9c000000' "$artifact_dir/early-probe-disassembly.txt"
grep -q '0xff00ff00ff00ff00' "$artifact_dir/early-probe-disassembly.txt"
grep -q '[[:space:]]wfe$' "$artifact_dir/early-probe-disassembly.txt"
grep -q '^CONFIG_USB_FUNCTION_FASTBOOT=y$' "$artifact_dir/u-boot.config"
grep -q '^CONFIG_FASTBOOT_BUF_ADDR=0x1A000000$' "$artifact_dir/u-boot.config"
grep -q '^CONFIG_FASTBOOT_BUF_SIZE=0x7000000$' "$artifact_dir/u-boot.config"
grep -q '^CONFIG_SYS_BOOTM_LEN=0x8000000$' "$artifact_dir/u-boot.config"
grep -q '^CONFIG_GZIP=y$' "$artifact_dir/u-boot.config"
grep -q '^CONFIG_ENV_DEFAULT_ENV_TEXT_FILE="board/qualcomm/tb371fc-stage0.env"$' \
	"$artifact_dir/u-boot.config"
grep -qx 'serial#=TB371FC-UBOOT' "$artifact_dir/tb371fc-stage0.env"
if grep -q '^fastboot_addr_r=' "$artifact_dir/tb371fc-stage0.env"; then
	echo 'The runtime LMB fastboot address must not have a static fallback.' >&2
	exit 1
fi
grep -a -q 'fastboot_addr_r' "$artifact_dir/u-boot-nodtb.bin"
grep -qx 'fastboot=fastboot -l \$fastboot_addr_r usb 0' \
	"$artifact_dir/tb371fc-stage0.env"
grep -q '^bootcmd=run fastboot$' "$artifact_dir/tb371fc-stage0.env"
grep -q '^fastboot_bootcmd=bootm \$fastboot_addr_r$' \
	"$artifact_dir/tb371fc-stage0.env"
grep -q '^Hardware status: OFFLINE ONLY; NOT FLASHED$' "$artifact_dir/BUILD-INFO.txt"

python3 - "$artifact_dir/u-boot-nodtb.bin" <<'PY'
import struct
import sys
from pathlib import Path

image = Path(sys.argv[1]).read_bytes()
if len(image) < 64 or image[56:60] != b"ARM\x64":
    raise SystemExit("U-Boot artifact has no ARM64 Image header")
text_offset, image_size, flags = struct.unpack_from("<QQQ", image, 8)
if text_offset != 0x80000:
    raise SystemExit(f"unexpected U-Boot text_offset: {text_offset:#x}")
if image_size < len(image):
    raise SystemExit("U-Boot ARM64 image_size does not cover the binary")
if flags != 0xA:
    raise SystemExit(f"unexpected U-Boot ARM64 flags: {flags:#x}")
PY

echo "TB371FC U-Boot stage-0 artifact verified (offline only)."
