#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
build_dir=${BUILD_DIR:-/root/tb371fc-linux-7.1.7-display-test-out}
kernel_dir=${KERNEL_DIR:-/root/tb371fc-linux-7.1.7-full-panel-verify}
package_dir=${PACKAGE_DIR:-/mnt/d/TB371FC-builds/mainline-7.1.7-native-display-test}
recovery="$package_dir/tb371fc-mainline-7.1.7-native-display-recovery.img"
initramfs="$package_dir/tb371fc-mainline-display-initramfs.cpio.gz"
kernel="$build_dir/arch/arm64/boot/Image"
dtb="$build_dir/arch/arm64/boot/dts/qcom/sm8250-lenovo-tb371fc-display-test.dtb"
stock="$project_dir/artifacts/device-backup/lun0-recovery_b.bin"
expected_recovery=${EXPECTED_RECOVERY_SHA256:-d366321efdf9b87d1e635830c23d2a7a2014313bd8ba9f47cf09564d5bb1da1e}
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT

python3 "$project_dir/scripts/verify-mainline-dsc-pps.py"
python3 "$project_dir/scripts/verify-mainline-tianma-command-table.py"
python3 "$project_dir/scripts/verify-mainline-display-timing.py"
python3 "$project_dir/scripts/verify-mainline-panel-order.py" "$kernel_dir"

"$project_dir/scripts/verify-diagnostic-recovery.sh" \
	/root/mkbootimg/unpack_bootimg.py \
	/root/avb/avbtool.py \
	"$recovery" "$stock" "$kernel" "$initramfs" "$dtb" \
	"$expected_recovery"

(
	cd "$stage"
	gzip -dc "$initramfs" | cpio -idmu 2>/dev/null
	file bin/busybox | grep -q 'ARM aarch64.*statically linked'
	file bin/framebuffer-pattern | grep -q 'ARM aarch64.*statically linked'
	test -x init
	test -x bin/setup-usb-console
	grep -Fq 'framebuffer-pattern /dev/fb0' init
	grep -Fq 'acm+ncm' init
	grep -Fq 'acm+ncm' bin/setup-usb-console
	grep -Fq '169.254.77.2/16' init
	grep -Fq 'nc -lk -p 2323' init
)

dtc -I dtb -O dts "$dtb" -o "$stage/display.dts" 2>/dev/null
grep -Fq 'compatible = "simple-framebuffer"' "$stage/display.dts"
grep -Fq 'compatible = "lenovo,tb371fc-tianma-nt36532' "$stage/display.dts"
grep -Fq 'compatible = "lenovo,tb371fc-ktz8866"' "$stage/display.dts"
grep -Fq 'power-domains =' "$stage/display.dts"

for option in \
	CONFIG_DRM_MSM=y \
	CONFIG_DRM_DISPLAY_HELPER=y \
	CONFIG_DRM_DISPLAY_DSC_HELPER=y \
	CONFIG_QCOM_OCMEM=y \
	CONFIG_QCOM_LLCC=y \
	CONFIG_DRM_PANEL_NOVATEK_NT36523=y \
	CONFIG_BACKLIGHT_TB371FC_KTZ8866=y \
	CONFIG_FB_SIMPLE=y \
	CONFIG_FRAMEBUFFER_CONSOLE=y \
	CONFIG_USB_CONFIGFS=y \
	CONFIG_USB_F_ACM=y \
	CONFIG_USB_F_NCM=y; do
	grep -Fxq "$option" "$build_dir/.config"
done

echo "Verified mainline native-display package, initramfs tools and DTB contract."
sha256sum "$kernel" "$dtb" "$initramfs" "$recovery"
