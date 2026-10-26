#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
output_dir=/mnt/d/TB371FC-builds/arch-development-loader-v29-kexec-bridge
image="$output_dir/tb371fc-arch-development-loader-v29-kexec-bridge-recovery.img"
kernel="$output_dir/Image-v29-kexec-bridge"
ramdisk="$output_dir/initramfs-v29-kexec-bridge.cpio.gz"
stock_recovery="$project_dir/artifacts/device-backup/lun0-recovery_b.bin"
v28_recovery=/mnt/d/TB371FC-builds/arch-development-loader-v28-pre-on-dsc-pps/tb371fc-arch-development-loader-v28-pre-on-dsc-pps-recovery.img
expected_sha256=88807d100ba8111f17502e52187e97a543eaab2853689987e453afc0dca950f2
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

for helper in start-kexec-receiver load-mainline-kexec execute-mainline-kexec; do
	cmp "$project_dir/initramfs/$helper" "$stage/ramdisk/bin/$helper"
done
cmp "$project_dir/initramfs/init-development" "$stage/ramdisk/init"
cmp "$project_dir/initramfs/boot-arch-development-rootfs" \
	"$stage/ramdisk/bin/boot-arch-development-rootfs"
file "$stage/ramdisk/bin/kexec" | grep -q 'ARM aarch64.*statically linked'
test "$(sha256sum "$stage/ramdisk/bin/kexec" | cut -d' ' -f1)" = \
	6c3c706315389d30638cc5fbb5482c069d8f411b6bb0ae298a8b25db319ae77d
grep -q '^CONFIG_KEXEC=y$' /root/tb371fc-lenovo-4.19-v29-kexec-bridge-out/.config
grep -q '^CONFIG_KEXEC_CORE=y$' /root/tb371fc-lenovo-4.19-v29-kexec-bridge-out/.config
grep -q ' machine_kexec$' /root/tb371fc-lenovo-4.19-v29-kexec-bridge-out/System.map
grep -q ' __cpu_soft_restart$' /root/tb371fc-lenovo-4.19-v29-kexec-bridge-out/System.map

echo 'Verified v29 kexec bridge kernel, recovery, initramfs helpers and static ARM64 kexec.'
sha256sum "$kernel" "$ramdisk" "$image" "$stage/ramdisk/bin/kexec"
