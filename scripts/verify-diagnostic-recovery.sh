#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
set -euo pipefail

if (( $# != 8 )); then
	echo "Usage: $0 UNPACK_BOOTIMG_PY AVBTOOL_PY RECOVERY_IMG STOCK_RECOVERY IMAGE INITRAMFS DTB EXPECTED_SHA256" >&2
	exit 2
fi

unpack_bootimg=$(realpath "$1")
avbtool=$(realpath "$2")
recovery_img=$(realpath "$3")
stock_recovery=$(realpath "$4")
kernel=$(realpath "$5")
initramfs=$(realpath "$6")
dtb=$(realpath "$7")
expected_sha256=$8
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT

python3 "$unpack_bootimg" --boot_img "$recovery_img" --out "$stage/test" --format info >"$stage/test-info.txt"
python3 "$unpack_bootimg" --boot_img "$stock_recovery" --out "$stage/stock" --format info >"$stage/stock-info.txt"
cat "$stage/test-info.txt"

if [[ -n ${RECOVERY_DTBO:-} ]]; then
	recovery_dtbo=$(realpath "$RECOVERY_DTBO")
else
	recovery_dtbo="$stage/stock/recovery_dtbo"
fi

grep -q '^boot magic: ANDROID!$' "$stage/test-info.txt"
grep -q '^boot image header version: 2$' "$stage/test-info.txt"
grep -q '^page size: 4096$' "$stage/test-info.txt"
cmp "$kernel" "$stage/test/kernel"
cmp "$initramfs" "$stage/test/ramdisk"
cmp "$dtb" "$stage/test/dtb"
cmp "$recovery_dtbo" "$stage/test/recovery_dtbo"
gzip -t "$initramfs"
ln -s "$recovery_img" "$stage/recovery.img"
python3 "$avbtool" verify_image --image "$stage/recovery.img"
avb_info=$(python3 "$avbtool" info_image --image "$recovery_img")
printf '%s\n' "$avb_info"
grep -q '^Footer version:           1\.0$' <<<"$avb_info"
grep -q '^Image size:               104857600 bytes$' <<<"$avb_info"
grep -q '^Algorithm:                NONE$' <<<"$avb_info"
grep -q '^      Partition Name:        recovery$' <<<"$avb_info"
grep -q '^      Salt:                  55e325516e7ae7202f867f2b02712affc4677aff76b16857e3d7875c403ef1e5$' <<<"$avb_info"
grep -Fq "com.android.build.recovery.fingerprint -> 'Lenovo/TB371FC_PRC/TB371FC:14/UKQ1.231222.001/ZUI_16.0.474_241129_PRC:user/release-keys'" <<<"$avb_info"

actual_sha256=$(sha256sum "$recovery_img" | awk '{print $1}')
if [[ $actual_sha256 != "$expected_sha256" ]]; then
	echo "Recovery image SHA-256 mismatch: expected $expected_sha256, got $actual_sha256" >&2
	exit 1
fi

max_size=$((100 * 1024 * 1024))
actual_size=$(stat -c %s "$recovery_img")
if (( actual_size != max_size )); then
	echo "AVB recovery image does not exactly fill the 100 MiB recovery_b partition" >&2
	exit 1
fi

echo "Verified recovery kernel, ramdisk and DTB byte-for-byte."
echo "Verified recovery_dtbo is byte-identical to the selected input."
printf 'Size: %d bytes (limit: %d)\n' "$actual_size" "$max_size"
sha256sum "$recovery_img" "$stock_recovery" "$kernel" "$initramfs" "$dtb" "$recovery_dtbo"
