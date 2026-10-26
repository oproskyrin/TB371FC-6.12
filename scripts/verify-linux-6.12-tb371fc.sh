#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

release_dir=${1:?Usage: verify-linux-6.12-tb371fc.sh RELEASE_DIR}
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
test -f "$release_dir/BUILD-INFO.txt"
(cd "$release_dir" && sha256sum -c SHA256SUMS)
file "$release_dir/Image" | grep -Fq 'Linux kernel ARM64 boot executable Image'
gzip -t "$release_dir/initramfs-6.12-arch-development.cpio.gz"
gzip -dc "$release_dir/initramfs-6.12-arch-development.cpio.gz" >"$work/initramfs.cpio"
cpio -it --quiet <"$work/initramfs.cpio" | \
	awk '$0 == "init" { found = 1 } END { exit !found }'
tar -tzf "$release_dir"/modules-*.tar.gz | \
	awk '/^lib\/modules\// { found = 1 } END { exit !found }'

simplefb="$release_dir/dtb/qcom/sm8250-lenovo-tb371fc-archsafe-microsd.dtb"
decoded=$(dtc -I dtb -O dts "$simplefb" 2>/dev/null)
grep -Fq 'framebuffer@9c000000' <<<"$decoded"
grep -Fq 'width = <0xb80>' <<<"$decoded"
grep -Fq 'height = <0x730>' <<<"$decoded"
grep -Fq 'mmc@8804000' <<<"$decoded"
grep -Fq 'redriver-power-gpios' <<<"$decoded"
grep -Fq 'max-frequency = <0x17d7840>' <<<"$decoded"
grep -Eq '^CONFIG_KEXEC=y$' "$release_dir"/config-*
grep -Eq '^CONFIG_USB_CONFIGFS_NCM=y$' "$release_dir"/config-*
grep -Eq '^CONFIG_(FB_SIMPLE|DRM_SIMPLEDRM)=y$' "$release_dir"/config-*
grep -Eq '^CONFIG_COMMON_CLK_QCOM=y$' "$release_dir"/config-*
grep -Eq '^CONFIG_SM_GCC_8250=y$' "$release_dir"/config-*
grep -Eq '^CONFIG_QCOM_AOSS_QMP=y$' "$release_dir"/config-*
grep -Eq '^CONFIG_NVMEM_QCOM_QFPROM=y$' "$release_dir"/config-*

if grep -Fq 'profile=desktop' "$release_dir/BUILD-INFO.txt"; then
	grep -Eq '^CONFIG_DRM_MSM=y$' "$release_dir"/config-*
	grep -Eq '^CONFIG_SM_GPUCC_8250=y$' "$release_dir"/config-*
	grep -Fq 'qcom/sm8250/lenovo/tb371fc/a650_zap.mbn' <<<"$decoded"
	firmware_archive=$(echo "$release_dir"/firmware-a650-*.tar.gz)
	test -s "$firmware_archive"
	tar -tzf "$firmware_archive" >"$work/firmware.list"
	grep -Fq 'usr/lib/firmware/qcom/a650_sqe.fw' "$work/firmware.list"
	grep -Fq 'usr/lib/firmware/qcom/a650_gmu.bin' "$work/firmware.list"
	grep -Fq 'usr/lib/firmware/qcom/sm8250/lenovo/tb371fc/a650_zap.mbn' "$work/firmware.list"
	strings "$work/initramfs.cpio" >"$work/initramfs.strings"
	grep -Fq 'usr/lib/firmware/qcom/a650_sqe.fw' "$work/initramfs.strings"
	grep -Fq 'usr/lib/firmware/qcom/a650_gmu.bin' "$work/initramfs.strings"
fi

echo "Verified Linux 6.12 TB371FC package: $release_dir"
