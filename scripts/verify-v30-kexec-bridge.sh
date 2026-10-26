#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
output_dir=/mnt/d/TB371FC-builds/arch-development-loader-v30-longwrite-kexec-bridge
image="$output_dir/tb371fc-arch-development-loader-v30-longwrite-kexec-bridge-recovery.img"
kernel="$output_dir/Image-v30-longwrite-kexec-bridge"
ramdisk="$output_dir/initramfs-v30-longwrite-kexec-bridge.cpio.gz"
stock_recovery="$project_dir/artifacts/device-backup/lun0-recovery_b.bin"
v28_recovery=/mnt/d/TB371FC-builds/arch-development-loader-v28-pre-on-dsc-pps/tb371fc-arch-development-loader-v28-pre-on-dsc-pps-recovery.img
expected_sha256=dc7bd05ce80312e5733b33867740596c83420ec828e1c03d1b0981fa8fc96089
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
grep -Fq '0afcf25e382deafdc277d9fa10ffb8b62474fcbea297bda7c40d5778b36b6170' \
	"$stage/ramdisk/bin/load-mainline-kexec"
grep -q '^CONFIG_KEXEC=y$' /root/tb371fc-lenovo-4.19-v29-kexec-bridge-out/.config
grep -q '^CONFIG_KEXEC_CORE=y$' /root/tb371fc-lenovo-4.19-v29-kexec-bridge-out/.config
grep -q ' machine_kexec$' /root/tb371fc-lenovo-4.19-v29-kexec-bridge-out/System.map
grep -q ' __cpu_soft_restart$' /root/tb371fc-lenovo-4.19-v29-kexec-bridge-out/System.map

echo 'Verified v30 long-write kexec bridge, recovery, helpers and payload allowlist.'
sha256sum "$kernel" "$ramdisk" "$image" "$stage/ramdisk/bin/kexec"
