#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source_dir=${SOURCE_DIR:-/mnt/d/TB371FC-builds/mainline-7.1.7-native-display-phycfg-v4}
output_dir=${OUTPUT_DIR:-/mnt/d/TB371FC-builds/mainline-7.1.7-native-display-phycfg-boot-v6}
busybox=${BUSYBOX:-/root/tb371fc-static-tools/busybox-aarch64}
source_kernel="$source_dir/Image-7.1.7-tb371fc-native-display-phycfg-v4"
kernel="$output_dir/Image-7.1.7-tb371fc-native-display-phycfg-v6-text80000"
ramdisk="$output_dir/tb371fc-mainline-display-initramfs-v6.cpio.gz"
dtb="$source_dir/sm8250-lenovo-tb371fc-display-test.dtb"
output="$output_dir/tb371fc-mainline-7.1.7-native-display-phycfg-v6-boot.img"
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT

for input in "$source_kernel" "$dtb" "$busybox"; do
	[[ -s $input ]] || { echo "Missing package input: $input" >&2; exit 1; }
done
[[ ! -e $output_dir ]] || { echo "Refusing to overwrite $output_dir" >&2; exit 1; }
mkdir -p "$output_dir"

"$project_dir/scripts/build-mainline-display-initramfs.sh" "$busybox" "$ramdisk"

python3 "$project_dir/scripts/make-arm64-text-offset-image.py" \
	"$source_kernel" "$kernel" --text-offset 0x80000

export DIAGNOSTIC_CMDLINE='earlycon=qcom_geni,0x988000 console=ttyMSM0,115200n8 console=tty0 fbcon=font:TER16x32 keep_bootcon ignore_loglevel initcall_debug drm.debug=0x1ff log_buf_len=4M rdinit=/init root=/dev/ram0 rw fw_devlink=permissive clk_ignore_unused pd_ignore_unused panic=-1 swiotlb=2048'

"$project_dir/scripts/build-diagnostic-boot.sh" \
	/root/mkbootimg/mkbootimg.py \
	"$kernel" "$ramdisk" "$dtb" "$stage/boot.img"

install -m0644 "$stage/boot.img" "$output"
python3 /root/avb/avbtool.py add_hash_footer \
	--image "$output" \
	--partition_size $((96 * 1024 * 1024)) \
	--partition_name boot \
	--algorithm NONE \
	--hash_algorithm sha256 \
	--salt 55e325516e7ae7202f867f2b02712affc4677aff76b16857e3d7875c403ef1e5 \
	--prop 'com.android.build.boot.fingerprint:Lenovo/TB371FC_PRC/TB371FC:14/UKQ1.231222.001/ZUI_16.0.474_241129_PRC:user/release-keys' \
	--prop 'com.android.build.boot.os_version:11' \
	--prop 'com.android.build.boot.security_patch:2024-02-05'

test "$(stat -c %s "$output")" -eq $((96 * 1024 * 1024))
sha256sum "$kernel" "$ramdisk" "$dtb" "$output"
