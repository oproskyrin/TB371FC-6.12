#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

profile=${1:-safe}
kernel_dir=${KERNEL_DIR:-/root/tb371fc/linux-6.12-donor}
jobs=${JOBS:-$(nproc)}

case "$profile" in
	safe)
		out_dir=${OUT_DIR:-/root/tb371fc/build-6.12-safe}
		fragments=(arch/arm64/configs/vendor/tb371fc_arch_safe.config)
		;;
	desktop)
		out_dir=${OUT_DIR:-/root/tb371fc/build-6.12-desktop}
		fragments=(
			arch/arm64/configs/vendor/tb371fc_arch_safe.config
			arch/arm64/configs/vendor/tb371fc_arch_desktop.config
		)
		;;
	*) echo "Usage: $0 [safe|desktop]" >&2; exit 2 ;;
esac

if [[ -n ${EXTRA_CONFIG:-} ]]; then
	fragments+=("$EXTRA_CONFIG")
fi

config_inputs=()
for fragment in "${fragments[@]}"; do
	if [[ $fragment = /* ]]; then
		config_inputs+=("$fragment")
	else
		config_inputs+=("$kernel_dir/$fragment")
	fi
done

test -d "$kernel_dir/.git"
mkdir -p "$out_dir"
make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 \
	vendor/tb371fc_defconfig
"$kernel_dir/scripts/kconfig/merge_config.sh" -m -O "$out_dir" \
	"$out_dir/.config" "${config_inputs[@]}"
make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 olddefconfig

require_config() {
	local symbol=$1
	grep -qx "${symbol}=y" "$out_dir/.config" || {
		echo "Required built-in kernel option is missing: ${symbol}=y" >&2
		exit 1
	}
}

for symbol in \
	CONFIG_COMMON_CLK_QCOM \
	CONFIG_SM_GCC_8250 \
	CONFIG_QCOM_AOSS_QMP \
	CONFIG_NVMEM_QCOM_QFPROM; do
	require_config "$symbol"
done
if [[ $profile == desktop ]]; then
	for symbol in CONFIG_DRM_MSM CONFIG_SM_GPUCC_8250; do
		require_config "$symbol"
	done
fi

make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 -j"$jobs" \
	Image dtbs modules

make -s -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 kernelrelease
sha256sum \
	"$out_dir/arch/arm64/boot/Image" \
	"$out_dir/arch/arm64/boot/dts/qcom/sm8250-lenovo-tb371fc.dtb" \
	"$out_dir/arch/arm64/boot/dts/qcom/sm8250-lenovo-tb371fc-archsafe-microsd.dtb" \
	"$out_dir/arch/arm64/boot/dts/qcom/sm8250-lenovo-tb371fc-simplefb.dtb"
