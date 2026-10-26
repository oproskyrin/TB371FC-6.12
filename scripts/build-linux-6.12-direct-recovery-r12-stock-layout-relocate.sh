#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-arch612-diag39+-safe-diag39-r2
output=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-direct-recovery-r12-stock-layout-relocate
stage0=/mnt/d/TB371FC-builds/diagnostic-7.1.8-stage0-minimal-direct-text-offset-empty-dtbo-recovery-7.1.8.img
payload_offset=$((0x1000))
wrapper=$output/Image-6.12.30-stock-layout-relocation-wrapper
image=$output/recovery.img

test ! -e "$output" || { echo "Refusing to overwrite $output" >&2; exit 1; }
mkdir -p "$output/stage0-unpack"
aarch64-linux-gnu-gcc -c -x assembler-with-cpp -nostdlib -ffreestanding \
	-o "$output/shim.o" "$project/u-boot-port/abl-linux-relocation-shim.S"
aarch64-linux-gnu-ld -nostdlib -static \
	-T "$project/u-boot-port/abl-linux-relocation-shim.lds" \
	-o "$output/shim.elf" "$output/shim.o"
aarch64-linux-gnu-objcopy -O binary "$output/shim.elf" "$output/shim.bin"
test "$(stat -c %s "$output/shim.bin")" -le "$payload_offset"
truncate -s "$payload_offset" "$wrapper"
dd if="$output/shim.bin" of="$wrapper" conv=notrunc status=none
cat "$package/Image" >>"$wrapper"
python3 - "$wrapper" "$package/Image" "$payload_offset" <<'PY'
import hashlib, struct, sys
wrapper_path, image_path, offset_text = sys.argv[1:]
offset = int(offset_text, 0)
data = bytearray(open(wrapper_path, 'rb').read())
struct.pack_into('<Q', data, 16, len(data))
open(wrapper_path, 'wb').write(data)
wrapped = open(wrapper_path, 'rb').read()
real = open(image_path, 'rb').read()
assert wrapped[56:60] == b'ARM\x64'
assert wrapped[offset:] == real
print('wrapper sha256=' + hashlib.sha256(wrapped).hexdigest())
PY

python3 /root/mkbootimg/unpack_bootimg.py --boot_img "$stage0" \
	--out "$output/stage0-unpack" --format info >"$output/EMPTY-DTBO-SOURCE.txt"
test "$(stat -c %s "$output/stage0-unpack/recovery_dtbo")" = 359
export RECOVERY_DTBO=$output/stage0-unpack/recovery_dtbo
export KERNEL_OFFSET=0x00008000
export RAMDISK_OFFSET=0x01000000
export DTB_OFFSET=0x01f00000
export DIAGNOSTIC_CMDLINE='earlycon=qcom_geni,0x988000 console=ttyMSM0,115200n8 console=tty0 fbcon=font:TER16x32 keep_bootcon ignore_loglevel log_buf_len=8M rdinit=/init root=/dev/ram0 rw fw_devlink=permissive clk_ignore_unused pd_ignore_unused regulator_ignore_unused panic=-1 swiotlb=2048 androidboot.serialno=0000000000 androidboot.slot_suffix=_b androidboot.verifiedbootstate=orange'

"$project/scripts/build-diagnostic-recovery.sh" \
	/root/mkbootimg/mkbootimg.py /root/mkbootimg/unpack_bootimg.py \
	/root/avb/avbtool.py \
	"$project/artifacts/device-backup/lun0-recovery_b.bin" \
	"$wrapper" "$package/initramfs-6.12-arch-development.cpio.gz" \
	"$package/dtb/qcom/sm8250-lenovo-tb371fc-archsafe-microsd.dtb" "$image"

python3 /root/mkbootimg/unpack_bootimg.py --boot_img "$image" \
	--out "$output/unpacked" --format info >"$output/UNPACK-INFO.txt"
python3 /root/avb/avbtool.py verify_image --image "$image"
grep -q '^kernel load address: 0x00008000$' "$output/UNPACK-INFO.txt"
grep -q '^ramdisk load address: 0x01000000$' "$output/UNPACK-INFO.txt"
grep -q '^dtb address: 0x0000000001f00000$' "$output/UNPACK-INFO.txt"
cmp "$output/unpacked/kernel" "$wrapper"
cmp "$output/unpacked/ramdisk" "$package/initramfs-6.12-arch-development.cpio.gz"
cmp "$output/unpacked/dtb" "$package/dtb/qcom/sm8250-lenovo-tb371fc-archsafe-microsd.dtb"
cmp "$output/unpacked/recovery_dtbo" "$RECOVERY_DTBO"
sha256sum "$wrapper" "$package/Image" "$package/initramfs-6.12-arch-development.cpio.gz" \
	"$package/dtb/qcom/sm8250-lenovo-tb371fc-archsafe-microsd.dtb" \
	"$RECOVERY_DTBO" "$image" >"$output/SHA256SUMS"
cat "$output/UNPACK-INFO.txt"
cat "$output/SHA256SUMS"
