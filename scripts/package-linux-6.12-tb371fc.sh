#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

profile=${1:-safe}
kernel_dir=${KERNEL_DIR:-/root/tb371fc/linux-6.12-donor}
base_initramfs=${BASE_INITRAMFS:-/mnt/d/TB371FC-builds/linux-7.1.8-tb371fc-r7-kexec-ram-test/initramfs-7.1.8-r7-arch-development.cpio.gz}
firmware_dir=${FIRMWARE_DIR:-/mnt/d/TB371FC-builds/tb371fc-linux-firmware-a650-r1}
release_revision=${RELEASE_REVISION:-r1}

case "$profile" in
	safe) out_dir=${OUT_DIR:-/root/tb371fc/build-6.12-safe} ;;
	desktop) out_dir=${OUT_DIR:-/root/tb371fc/build-6.12-desktop} ;;
	*) echo "Usage: $0 [safe|desktop]" >&2; exit 2 ;;
esac

kernel_release=$(make -s -C "$kernel_dir" O="$out_dir" ARCH=arm64 \
	LLVM=-18 kernelrelease)
release_dir=${RELEASE_DIR:-/mnt/d/TB371FC-builds/linux-${kernel_release}-${profile}-${release_revision}}
module_stage=$(mktemp -d)
initramfs_stage=$(mktemp -d)
trap 'rm -rf -- "$module_stage" "$initramfs_stage"' EXIT

test -s "$out_dir/arch/arm64/boot/Image"
test -s "$out_dir/arch/arm64/boot/dts/qcom/sm8250-lenovo-tb371fc-archsafe-microsd.dtb"
test -s "$base_initramfs"
test ! -e "$release_dir" || {
	echo "Refusing to overwrite: $release_dir" >&2
	exit 1
}

install -d -m0755 "$release_dir/dtb/qcom"
install -m0644 "$out_dir/arch/arm64/boot/Image" "$release_dir/Image"
install -m0644 "$out_dir/arch/arm64/boot/dts/qcom/sm8250-lenovo-tb371fc.dtb" \
	"$release_dir/dtb/qcom/"
install -m0644 "$out_dir/arch/arm64/boot/dts/qcom/sm8250-lenovo-tb371fc-simplefb.dtb" \
	"$release_dir/dtb/qcom/"
install -m0644 "$out_dir/arch/arm64/boot/dts/qcom/sm8250-lenovo-tb371fc-archsafe.dtb" \
	"$release_dir/dtb/qcom/"
install -m0644 "$out_dir/arch/arm64/boot/dts/qcom/sm8250-lenovo-tb371fc-archsafe-microsd.dtb" \
	"$release_dir/dtb/qcom/"
install -m0644 "$out_dir/.config" "$release_dir/config-$kernel_release"
install -m0644 "$out_dir/System.map" "$release_dir/System.map-$kernel_release"

make -s -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 \
	INSTALL_MOD_STRIP=1 INSTALL_MOD_PATH="$module_stage" modules_install
tar -C "$module_stage" -czf "$release_dir/modules-$kernel_release.tar.gz" \
	lib/modules

install -d -m0755 "$initramfs_stage/overlay/usr/lib"
cp -a "$module_stage/lib/modules" "$initramfs_stage/overlay/usr/lib/"

if [[ $profile == desktop ]]; then
	required_firmware=(
		qcom/a650_sqe.fw
		qcom/a650_gmu.bin
		qcom/sm8250/lenovo/tb371fc/a650_zap.mbn
	)
	for firmware in "${required_firmware[@]}"; do
		test -s "$firmware_dir/$firmware" || {
			echo "Required A650 firmware is missing: $firmware_dir/$firmware" >&2
			exit 1
		}
		install -Dm0644 "$firmware_dir/$firmware" \
			"$initramfs_stage/overlay/usr/lib/firmware/$firmware"
	done
	for metadata in SOURCE.txt SHA256SUMS UPSTREAM-WHENCE.txt; do
		test ! -f "$firmware_dir/$metadata" || \
			install -Dm0644 "$firmware_dir/$metadata" \
				"$initramfs_stage/overlay/usr/share/tb371fc-firmware/$metadata"
	done
	tar -C "$initramfs_stage/overlay" -czf \
		"$release_dir/firmware-a650-$kernel_release.tar.gz" usr/lib/firmware usr/share/tb371fc-firmware
fi

(
	cd "$initramfs_stage/overlay"
	find . -print0 | LC_ALL=C sort -z | \
		cpio --null -o --format=newc --owner=0:0 --quiet \
		>"$initramfs_stage/overlay.cpio"
)
gzip -dc "$base_initramfs" >"$initramfs_stage/combined.cpio"
dd if="$initramfs_stage/overlay.cpio" of="$initramfs_stage/combined.cpio" \
	oflag=append conv=notrunc status=none
gzip -n -9 -c "$initramfs_stage/combined.cpio" \
	>"$release_dir/initramfs-6.12-arch-development.cpio.gz"
gzip -t "$release_dir/initramfs-6.12-arch-development.cpio.gz"

printf '%s\n' \
	'console=tty0 fbcon=font:TER16x32 ignore_loglevel log_buf_len=4M rdinit=/init root=/dev/ram0 rw fw_devlink=permissive clk_ignore_unused pd_ignore_unused regulator_ignore_unused panic=-1 swiotlb=2048' \
	>"$release_dir/KEXEC-CMDLINE.txt"

{
	echo 'platform=Lenovo TB371FC'
	echo "profile=$profile"
	echo "kernel_release=$kernel_release"
	echo "kernel_commit=$(git -C "$kernel_dir" rev-parse HEAD)"
	echo 'boot_stage=V56.3-r3.3 kexec RAM test; no Android/UFS mount'
	echo 'display_stage=firmware simple-framebuffer 2944x1840; native DSI disabled'
	echo 'gpu_stage=upstream DRM_MSM/A650 enabled; render-node probe before native KMS'
	if [[ $profile == desktop ]]; then
		echo "firmware_source=$firmware_dir"
		echo 'firmware_contract=qcom/a650_sqe.fw qcom/a650_gmu.bin qcom/sm8250/lenovo/tb371fc/a650_zap.mbn'
	fi
	echo 'root_stage=microSD SDHCI2 3.3V 25MHz with GPIO75 redriver sequencing'
	echo 'rollback=V56.3-r3.3 remains installed and immutable'
	echo 'status=OFFLINE VERIFIED; NOT YET BOOTED ON HARDWARE'
} >"$release_dir/BUILD-INFO.txt"

(
	cd "$release_dir"
	find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum
) >"$release_dir/SHA256SUMS"
(cd "$release_dir" && sha256sum -c SHA256SUMS)
echo "$release_dir"
