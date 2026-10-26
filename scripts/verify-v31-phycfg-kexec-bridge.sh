#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
output_dir=/mnt/d/TB371FC-builds/arch-development-loader-v31-phycfg-kexec-bridge
image="$output_dir/tb371fc-arch-development-loader-v31-phycfg-kexec-bridge-recovery.img"
kernel="$output_dir/Image-v31-phycfg-kexec-bridge"
ramdisk="$output_dir/initramfs-v31-phycfg-kexec-bridge.cpio.gz"
stock_recovery="$project_dir/artifacts/device-backup/lun0-recovery_b.bin"
v28_recovery=/mnt/d/TB371FC-builds/arch-development-loader-v28-pre-on-dsc-pps/tb371fc-arch-development-loader-v28-pre-on-dsc-pps-recovery.img
expected_sha256=e071200b8888d4d32488b6f90223256387d4091953853cb08d7e2d816048bb76
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT

python3 /root/mkbootimg/unpack_bootimg.py \
	--boot_img "$v28_recovery" --out "$stage/v28" --format info \
	>"$stage/v28-info.txt"

"$project_dir/scripts/verify-diagnostic-recovery.sh" \
	/root/mkbootimg/unpack_bootimg.py \
	/root/avb/avbtool.py \
	"$image" "$stock_recovery" "$kernel" "$ramdisk" \
	"$stage/v28/dtb" "$expected_sha256"

mkdir "$stage/ramdisk"
(
	cd "$stage/ramdisk"
	gzip -dc "$ramdisk" | cpio -idmu 2>/dev/null
)

cmp "$project_dir/initramfs/load-mainline-kexec-v31" \
	"$stage/ramdisk/bin/load-mainline-kexec"
cmp "$project_dir/initramfs/execute-mainline-kexec" \
	"$stage/ramdisk/bin/execute-mainline-kexec"
file "$stage/ramdisk/bin/kexec" | grep -q 'ARM aarch64.*statically linked'
grep -Fq 'c21a05263b9271bade98f95b705f676da4c8f543d80e5f2ed503f839448840be' \
	"$stage/ramdisk/bin/load-mainline-kexec"
grep -Fq '69f68b1a30796986f1676c60faad11a0be8a861278f21e364c6af01eaf18182d' \
	"$stage/ramdisk/bin/load-mainline-kexec"
grep -Fq '423aeb496f5ff471073d52f444fc269c624055bee813239b8d87409ecf12bd2c' \
	"$stage/ramdisk/bin/load-mainline-kexec"
grep -q '^CONFIG_KEXEC=y$' /root/tb371fc-lenovo-4.19-v29-kexec-bridge-out/.config
grep -q ' machine_kexec$' /root/tb371fc-lenovo-4.19-v29-kexec-bridge-out/System.map

echo 'Verified v31 PHY-config kexec bridge, recovery, helpers and v4-only allowlist.'
sha256sum "$kernel" "$ramdisk" "$image" "$stage/ramdisk/bin/kexec"
