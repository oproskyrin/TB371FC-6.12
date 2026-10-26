#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-clean39-desktop-r1
output=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-direct-recovery-r8b-aligned-shim
stage0=/mnt/d/TB371FC-builds/diagnostic-7.1.8-stage0-minimal-direct-text-offset-empty-dtbo-recovery-7.1.8.img
shim_source="$project/u-boot-port/abl-linux-aligned-shim.S"
shim_linker="$project/u-boot-port/abl-linux-aligned-shim.lds"
wrapper=$output/Image-6.12.30-clean39-abl-aligned-wrapper
image=$output/recovery.img
payload_offset=$((0x180000))

test ! -e "$output" || {
	echo "Refusing to overwrite $output" >&2
	exit 1
}
mkdir -p "$output/stage0-unpack"

aarch64-linux-gnu-gcc -c -x assembler-with-cpp -nostdlib -ffreestanding \
	-o "$output/shim.o" "$shim_source"
aarch64-linux-gnu-ld -nostdlib -static -T "$shim_linker" \
	-o "$output/shim.elf" "$output/shim.o"
aarch64-linux-gnu-objcopy -O binary "$output/shim.elf" "$output/shim.bin"
test "$(stat -c %s "$output/shim.bin")" -le 4096

truncate -s "$payload_offset" "$wrapper"
dd if="$output/shim.bin" of="$wrapper" conv=notrunc status=none
cat "$package/Image" >>"$wrapper"

python3 - "$wrapper" "$package/Image" "$payload_offset" <<'PY'
import hashlib
import struct
import sys

wrapper_path, image_path, offset_text = sys.argv[1:]
offset = int(offset_text, 0)
with open(wrapper_path, "r+b") as stream:
    data = stream.read()
    total = len(data)
    if data[56:60] != b"ARM\x64":
        raise SystemExit("wrapper ARM64 magic missing")
    struct.pack_into("<Q", data := bytearray(data), 16, total)
    stream.seek(0)
    stream.write(data)

real = open(image_path, "rb").read()
wrapped = open(wrapper_path, "rb").read()
if wrapped[offset:] != real:
    raise SystemExit("embedded modern Image mismatch")
if (0x80080000 + offset) % 0x200000:
    raise SystemExit("embedded Image is not 2 MiB aligned")
print(f"wrapper size={len(wrapped)} payload_offset={offset:#x} entry={0x80080000 + offset:#x}")
print("wrapper sha256=" + hashlib.sha256(wrapped).hexdigest())
PY

python3 /root/mkbootimg/unpack_bootimg.py --boot_img "$stage0" \
	--out "$output/stage0-unpack" --format info >"$output/EMPTY-DTBO-SOURCE.txt"
test "$(stat -c %s "$output/stage0-unpack/recovery_dtbo")" = 359

export RECOVERY_DTBO=$output/stage0-unpack/recovery_dtbo
export DIAGNOSTIC_CMDLINE='earlycon=qcom_geni,0x988000 console=ttyMSM0,115200n8 console=tty0 fbcon=font:TER16x32 keep_bootcon ignore_loglevel log_buf_len=8M rdinit=/init root=/dev/ram0 rw fw_devlink=permissive clk_ignore_unused pd_ignore_unused regulator_ignore_unused panic=-1 swiotlb=2048 androidboot.serialno=0000000000 androidboot.slot_suffix=_b androidboot.verifiedbootstate=orange'

"$project/scripts/build-diagnostic-recovery.sh" \
	/root/mkbootimg/mkbootimg.py \
	/root/mkbootimg/unpack_bootimg.py \
	/root/avb/avbtool.py \
	"$project/artifacts/device-backup/lun0-recovery_b.bin" \
	"$wrapper" \
	"$package/initramfs-6.12-arch-development.cpio.gz" \
	"$package/dtb/qcom/sm8250-lenovo-tb371fc-archsafe-microsd.dtb" \
	"$image"

python3 /root/mkbootimg/unpack_bootimg.py --boot_img "$image" \
	--out "$output/unpacked" --format info >"$output/UNPACK-INFO.txt"
python3 /root/avb/avbtool.py verify_image --image "$image"
cmp "$output/unpacked/kernel" "$wrapper"
cmp "$output/unpacked/ramdisk" "$package/initramfs-6.12-arch-development.cpio.gz"
cmp "$output/unpacked/dtb" "$package/dtb/qcom/sm8250-lenovo-tb371fc-archsafe-microsd.dtb"
cmp "$output/unpacked/recovery_dtbo" "$RECOVERY_DTBO"
sha256sum "$wrapper" "$package/Image" "$RECOVERY_DTBO" "$image" >"$output/SHA256SUMS"
cat "$output/UNPACK-INFO.txt"
cat "$output/SHA256SUMS"
