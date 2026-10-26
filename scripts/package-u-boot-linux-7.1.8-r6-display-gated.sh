#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
release_dir=${RELEASE_DIR:-/mnt/d/TB371FC-builds/linux-7.1.8-tb371fc-r6-display-wideplane-offline}
busybox=${BUSYBOX:-/root/bin/busybox}
output_dir=${1:-/mnt/d/TB371FC-builds/u-boot-linux-7.1.8-r6-display-gated-payload}
mkbootimg=${MKBOOTIMG:-/root/mkbootimg/mkbootimg.py}
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT

[[ ! -e $output_dir ]] || { echo "Refusing to overwrite: $output_dir" >&2; exit 1; }
for input in "$release_dir/Image" \
	"$release_dir/dtb/qcom/sm8250-lenovo-tb371fc-display-test.dtb" \
	"$busybox" "$mkbootimg"; do
	[[ -s $input ]] || { echo "Missing package input: $input" >&2; exit 1; }
done
mkdir -p "$output_dir"

ramdisk="$output_dir/tb371fc-linux-7.1.8-display-gated-initramfs.cpio.gz"
"$project_dir/scripts/build-mainline-display-gated-initramfs.sh" "$busybox" "$ramdisk"
gzip -n -9 -c "$release_dir/Image" >"$stage/Image.gz"
gzip -t "$stage/Image.gz"
gzip -dc "$stage/Image.gz" | cmp - "$release_dir/Image"

cmdline='earlycon=qcom_geni,0x988000 console=ttyMSM0,115200n8 console=tty0 keep_bootcon ignore_loglevel initcall_debug drm.debug=0x1ff drm_kms_helper.fbdev_emulation=0 msm.fbdev=0 log_buf_len=8M rdinit=/init root=/dev/ram0 rw fw_devlink=permissive clk_ignore_unused pd_ignore_unused panic=-1 swiotlb=2048'
output="$output_dir/tb371fc-linux-7.1.8-display-gated-u-boot.img"
DIAGNOSTIC_CMDLINE="$cmdline" "$project_dir/scripts/build-diagnostic-boot.sh" \
	"$mkbootimg" "$stage/Image.gz" "$ramdisk" \
	"$release_dir/dtb/qcom/sm8250-lenovo-tb371fc-display-test.dtb" "$output"

{
	echo 'platform=Lenovo TB371FC'
	echo 'kernel_release=7.1.8-tb371fc'
	echo 'payload_kind=display-gated'
	echo 'transport=U-Boot fastboot download; RAM boot only'
	echo 'automatic_modeset=disabled'
	echo 'manual_modeset=run-mainline-display-test over USB shell'
	echo 'hardware_status=OFFLINE VERIFIED; NOT BOOTED'
	echo 'warning=Do not use fastboot flash. U-Boot has flash backend disabled.'
} >"$output_dir/README.txt"
(
	cd "$output_dir"
	find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum
) >"$output_dir/SHA256SUMS"
(cd "$output_dir" && sha256sum -c SHA256SUMS)
du -sh "$output_dir"
