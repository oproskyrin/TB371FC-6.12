#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-arch612-desktop+-desktop-r4
output=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-direct-recovery-r6
kernel=$output/Image-6.12.30-abl-compatible
image=$output/recovery.img

test ! -e "$output" || {
	echo "Refusing to overwrite $output" >&2
	exit 1
}
mkdir -p "$output"
cp "$package/Image" "$kernel"

# Lenovo ABL follows the downstream ARM64 Image convention used by the stock
# and V56 kernels: a branch in code0, zero in code1 and text_offset 0x80000.
# Android common 6.12 emits the newer PE-compatible NOP/B pair with an
# effective text_offset of zero. Move the branch four bytes earlier and add
# one instruction to its displacement so the exact original target is kept.
python3 - "$kernel" <<'PY'
import struct
import sys

path = sys.argv[1]
with open(path, "r+b") as stream:
    header = bytearray(stream.read(64))
    code0, code1, text_offset = struct.unpack_from("<IIQ", header)
    if code0 != 0xD503201F or code1 & 0xFC000000 != 0x14000000:
        raise SystemExit(f"unexpected modern Image entry: {code0:08x} {code1:08x}")
    if text_offset != 0:
        raise SystemExit(f"unexpected source text_offset: {text_offset:#x}")
    old_imm = code1 & 0x03FFFFFF
    new_imm = (old_imm + 1) & 0x03FFFFFF
    new_code0 = 0x14000000 | new_imm
    old_target = 4 + ((old_imm if old_imm < 0x02000000 else old_imm - 0x04000000) << 2)
    new_target = ((new_imm if new_imm < 0x02000000 else new_imm - 0x04000000) << 2)
    if old_target != new_target:
        raise SystemExit("ABL trampoline changed the kernel entry target")
    struct.pack_into("<IIQ", header, 0, new_code0, 0, 0x80000)
    stream.seek(0)
    stream.write(header)
    print(f"ABL trampoline: B {new_target:#x}; text_offset=0x80000")
PY

export DIAGNOSTIC_CMDLINE='earlycon=qcom_geni,0x988000 console=ttyMSM0,115200n8 console=tty0 fbcon=font:TER16x32 keep_bootcon ignore_loglevel log_buf_len=8M rdinit=/init root=/dev/ram0 rw fw_devlink=permissive clk_ignore_unused pd_ignore_unused regulator_ignore_unused panic=-1 swiotlb=2048 androidboot.serialno=0000000000 androidboot.slot_suffix=_b androidboot.verifiedbootstate=orange'

"$project/scripts/build-diagnostic-recovery.sh" \
	/root/mkbootimg/mkbootimg.py \
	/root/mkbootimg/unpack_bootimg.py \
	/root/avb/avbtool.py \
	"$project/artifacts/device-backup/lun0-recovery_b.bin" \
	"$kernel" \
	"$package/initramfs-6.12-arch-development.cpio.gz" \
	"$package/dtb/qcom/sm8250-lenovo-tb371fc-archsafe-microsd.dtb" \
	"$image"

python3 /root/mkbootimg/unpack_bootimg.py \
	--boot_img "$image" --out "$output/unpacked" --format info \
	>"$output/UNPACK-INFO.txt"
python3 /root/avb/avbtool.py verify_image --image "$image"
cmp "$output/unpacked/kernel" "$kernel"
cmp "$output/unpacked/ramdisk" \
	"$package/initramfs-6.12-arch-development.cpio.gz"
cmp "$output/unpacked/dtb" \
	"$package/dtb/qcom/sm8250-lenovo-tb371fc-archsafe-microsd.dtb"
sha256sum "$kernel" "$image" >"$output/SHA256SUMS"
cat "$output/UNPACK-INFO.txt"
cat "$output/SHA256SUMS"
