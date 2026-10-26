#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
kernel_dir=${KERNEL_DIR:-/root/tb371fc-linux-7.1.8-clean}
out_dir=${OUT_DIR:-/root/tb371fc-linux-7.1.8-clean-out}
artifact_dir=${1:-/root/tb371fc-linux-7.1.8-release}
module_stage=$(mktemp -d)
trap 'rm -rf -- "$module_stage"' EXIT

[[ -e $kernel_dir/.git ]] || { echo "Missing kernel worktree: $kernel_dir" >&2; exit 1; }
[[ -s $out_dir/arch/arm64/boot/Image ]] || { echo "Missing built Image" >&2; exit 1; }
[[ ! -e $artifact_dir ]] || { echo "Refusing to overwrite: $artifact_dir" >&2; exit 1; }

kernel_release=$(make -s -C "$kernel_dir" O="$out_dir" ARCH=arm64 \
	CROSS_COMPILE=aarch64-linux-gnu- LOCALVERSION= kernelrelease)
[[ $kernel_release == 7.1.8-tb371fc ]] || {
	echo "Unexpected kernel release: $kernel_release" >&2
	exit 1
}

install -d -m0755 "$artifact_dir/dtb/qcom"
install -m0644 "$out_dir/arch/arm64/boot/Image" "$artifact_dir/Image"
for name in \
	sm8250-lenovo-tb371fc \
	sm8250-lenovo-tb371fc-stage0 \
	sm8250-lenovo-tb371fc-arch-test \
	sm8250-lenovo-tb371fc-touch-test \
	sm8250-lenovo-tb371fc-display-test \
	sm8250-lenovo-tb371fc-gc08a3-test \
	sm8250-lenovo-tb371fc-s5k4h7-test; do
	install -m0644 "$out_dir/arch/arm64/boot/dts/qcom/$name.dtb" \
		"$artifact_dir/dtb/qcom/$name.dtb"
done
install -m0644 "$out_dir/.config" "$artifact_dir/config-$kernel_release"
install -m0644 "$out_dir/System.map" "$artifact_dir/System.map-$kernel_release"
install -m0644 "$out_dir/Module.symvers" "$artifact_dir/Module.symvers-$kernel_release"

make -s -C "$kernel_dir" O="$out_dir" ARCH=arm64 \
	CROSS_COMPILE=aarch64-linux-gnu- LOCALVERSION= KERNELRELEASE="$kernel_release" \
	INSTALL_MOD_STRIP=1 \
	INSTALL_MOD_PATH="$module_stage" modules_install
module_count=$(find "$module_stage/lib/modules/$kernel_release" -type f -name '*.ko*' | wc -l)
[[ $module_count -ge 1000 ]] || { echo "Too few installed modules: $module_count" >&2; exit 1; }
tar -C "$module_stage" -czf "$artifact_dir/modules-$kernel_release.tar.gz" lib/modules

(
	cd "$project_dir/mainline-port/patches"
	sha256sum -- *.patch
) >"$artifact_dir/PATCH-SHA256SUMS"
{
	echo 'platform=Lenovo TB371FC'
	echo "kernel_release=$kernel_release"
	echo "kernel_commit=$(git -C "$kernel_dir" rev-parse HEAD)"
	echo "module_count=$module_count"
	echo "build_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
	echo 'hardware_status=OFFLINE VERIFIED; NOT BOOTED'
	echo 'boot_contract=Qualcomm ABL -> U-Boot stage-0 -> Android boot image'
	echo 'display_contract=dual DSI, DSC 1.1, 2944x1840 at 120 Hz'
	echo 'input_contract=Novatek SPI touch/AP500U plus Lenovo I2C-HID keyboard cover GPIO sequence'
	echo 'source_worktree_status_begin'
	git -C "$kernel_dir" status --short
	echo 'source_worktree_status_end'
} >"$artifact_dir/BUILD-INFO.txt"

(
	cd "$artifact_dir"
	find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum
) >"$artifact_dir/SHA256SUMS"

echo "TB371FC Linux release artifact: $artifact_dir"
cat "$artifact_dir/BUILD-INFO.txt"
du -sh "$artifact_dir"
(cd "$artifact_dir" && sha256sum -c SHA256SUMS)
