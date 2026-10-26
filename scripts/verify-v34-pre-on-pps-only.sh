#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_tree=/root/tb371fc-lenovo-4.19-v34-pre-on-pps-only-src
out_tree=/root/tb371fc-lenovo-4.19-v34-pre-on-pps-only-out
output_dir=/mnt/d/TB371FC-builds/arch-development-loader-v34-pre-on-pps-only
image="$output_dir/tb371fc-arch-development-loader-v34-pre-on-pps-only-recovery.img"
kernel="$output_dir/Image-v34-pre-on-pps-only"
ramdisk="$output_dir/initramfs-v34-pre-on-pps-only-kexec.cpio.gz"
stock_recovery="$project_dir/artifacts/device-backup/lun0-recovery_b.bin"
v32_recovery=/mnt/d/TB371FC-builds/arch-development-loader-v32-nt36532-vendor-dsc/tb371fc-arch-development-loader-v32-nt36532-vendor-dsc-recovery.img
expected_sha256=205dae2250efbad6088406ce290818463d649540e8d895498fd51b3bea8285af
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT

python3 /root/mkbootimg/unpack_bootimg.py \
	--boot_img "$v32_recovery" --out "$stage/v32" --format info \
	>"$stage/v32-info.txt"

"$project_dir/scripts/verify-diagnostic-recovery.sh" \
	/root/mkbootimg/unpack_bootimg.py \
	/root/avb/avbtool.py \
	"$image" "$stock_recovery" "$kernel" "$ramdisk" \
	"$stage/v32/dtb" "$expected_sha256"

mkdir "$stage/ramdisk"
(cd "$stage/ramdisk" && gzip -dc "$ramdisk" | cpio -idmu 2>/dev/null)
for helper in kexec start-kexec-receiver load-mainline-kexec execute-mainline-kexec; do
	test -x "$stage/ramdisk/bin/$helper"
done
file "$stage/ramdisk/bin/kexec" | grep -q 'ARM aarch64.*statically linked'
test "$(sha256sum "$stage/ramdisk/bin/kexec" | cut -d' ' -f1)" = \
	6c3c706315389d30638cc5fbb5482c069d8f411b6bb0ae298a8b25db319ae77d

display="$source_tree/techpack/display/msm/dsi/dsi_display.c"
grep -q 'TB371FC cold path already sent PPS; post-ON PPS only for transition' "$display"
grep -q 'per_link_pic_width \* display->ctrl_count' "$display"
grep -q 'mode->dsi_mode_flags & (DSI_MODE_FLAG_DMS' "$display"
grep -q 'TB371FC cold path already sent PPS' "$kernel"
grep -q '^CONFIG_KEXEC=y$' "$out_tree/.config"
grep -q ' machine_kexec$' "$out_tree/System.map"

echo 'Verified v34 full-width pre-ON-only PPS, exact DTB, kexec kernel and static receiver tools.'
sha256sum "$kernel" "$ramdisk" "$image" "$stage/ramdisk/bin/kexec"
