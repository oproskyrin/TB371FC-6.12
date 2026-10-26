#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

artifact_dir=${1:-/root/tb371fc-linux-7.1.8-release}
release=7.1.8-tb371fc
module_list=$(mktemp)
trap 'rm -f -- "$module_list"' EXIT

for input in \
	"$artifact_dir/Image" \
	"$artifact_dir/config-$release" \
	"$artifact_dir/System.map-$release" \
	"$artifact_dir/Module.symvers-$release" \
	"$artifact_dir/modules-$release.tar.gz" \
	"$artifact_dir/BUILD-INFO.txt" \
	"$artifact_dir/PATCH-SHA256SUMS" \
	"$artifact_dir/SHA256SUMS"; do
	[[ -s $input ]] || { echo "Missing release artifact: $input" >&2; exit 1; }
done

(cd "$artifact_dir" && sha256sum -c SHA256SUMS)
grep -q '^kernel_release=7.1.8-tb371fc$' "$artifact_dir/BUILD-INFO.txt"
module_count=$(sed -n 's/^module_count=//p' "$artifact_dir/BUILD-INFO.txt")
[[ $module_count =~ ^[0-9]+$ && $module_count -ge 1000 ]]
grep -q '^hardware_status=OFFLINE VERIFIED; NOT BOOTED$' "$artifact_dir/BUILD-INFO.txt"
grep -q '^CONFIG_DRM_MSM=y$' "$artifact_dir/config-$release"
grep -q '^CONFIG_DRM_PANEL_NOVATEK_NT36523=y$' "$artifact_dir/config-$release"
grep -q '^CONFIG_TOUCHSCREEN_NT36523_SPI=m$' "$artifact_dir/config-$release"
grep -q '^CONFIG_ATH11K_PCI=m$' "$artifact_dir/config-$release"
grep -q '^CONFIG_HID_MULTITOUCH=y$' "$artifact_dir/config-$release"
grep -q '^CONFIG_I2C_HID_CORE=y$' "$artifact_dir/config-$release"
grep -q '^CONFIG_I2C_HID_OF=y$' "$artifact_dir/config-$release"
grep -q '^CONFIG_TYPEC_DP_ALTMODE=y$' "$artifact_dir/config-$release"
grep -q '^CONFIG_VIDEO_S5K4H7=m$' "$artifact_dir/config-$release"
grep -q '^CONFIG_BLK_DEV_LOOP=y$' "$artifact_dir/config-$release"
grep -q '^CONFIG_MMC_SDHCI_MSM=y$' "$artifact_dir/config-$release"
grep -q '^CONFIG_EXFAT_FS=y$' "$artifact_dir/config-$release"
grep -q '^CONFIG_USB_LIBCOMPOSITE=y$' "$artifact_dir/config-$release"
grep -q '^CONFIG_USB_F_ACM=y$' "$artifact_dir/config-$release"
grep -q '^CONFIG_USB_F_NCM=y$' "$artifact_dir/config-$release"
grep -q '^CONFIG_USB_CONFIGFS=y$' "$artifact_dir/config-$release"

for name in \
	sm8250-lenovo-tb371fc \
	sm8250-lenovo-tb371fc-stage0 \
	sm8250-lenovo-tb371fc-arch-test \
	sm8250-lenovo-tb371fc-touch-test \
	sm8250-lenovo-tb371fc-display-test \
	sm8250-lenovo-tb371fc-gc08a3-test \
	sm8250-lenovo-tb371fc-s5k4h7-test; do
	[[ -s $artifact_dir/dtb/qcom/$name.dtb ]] || { echo "Missing DTB: $name" >&2; exit 1; }
done

board_dtb="$artifact_dir/dtb/qcom/sm8250-lenovo-tb371fc.dtb"
arch_dtb="$artifact_dir/dtb/qcom/sm8250-lenovo-tb371fc-arch-test.dtb"
keyboard_node=/soc@0/geniqup@ac0000/i2c@a94000/keyboard-cover@60
sdhc_node=/soc@0/mmc@8804000
tlmm_node=/soc@0/pinctrl@f100000
rsc_node=/soc@0/rsc@18200000
[[ $(fdtget -t s "$board_dtb" "$keyboard_node" compatible) == hid-over-i2c ]]
[[ $(fdtget -t u "$board_dtb" "$keyboard_node" reg) == 96 ]]
[[ $(fdtget -t u "$board_dtb" "$keyboard_node" interrupts) == '110 8' ]]
[[ $(fdtget -t u "$board_dtb" "$keyboard_node" reset-gpios | awk '{print $2, $3}') == '114 1' ]]
[[ $(fdtget -t u "$board_dtb" "$keyboard_node" wake-gpios | awk '{print $2, $3}') == '108 0' ]]
[[ $(fdtget -t u "$board_dtb" "$keyboard_node" hid-descr-addr) == 1 ]]
[[ $(fdtget -t u "$board_dtb" "$keyboard_node" post-reset-deassert-delay-ms) == 120 ]]
[[ $(fdtget -t s "$arch_dtb" "$sdhc_node" status) == okay ]]
[[ $(fdtget -t u "$arch_dtb" "$sdhc_node" bus-width) == 4 ]]
[[ $(fdtget -t u "$arch_dtb" "$sdhc_node" max-frequency) == 25000000 ]]
[[ $(fdtget -t u "$arch_dtb" "$sdhc_node" cd-gpios | awk '{print $2, $3}') == '14 0' ]]
for property in no-1-8-v no-sdio no-mmc disable-wp; do
	fdtget -p "$arch_dtb" "$sdhc_node" | grep -qx "$property"
done
[[ $(fdtget -t u "$arch_dtb" "$sdhc_node" redriver-power-gpios | awk '{print $2, $3}') == '75 0' ]]
[[ $(fdtget -t s "$arch_dtb" "$rsc_node/regulators-1/ldo6" regulator-name) == vreg_l6c_2p96 ]]
[[ $(fdtget -t u "$arch_dtb" "$rsc_node/regulators-1/ldo6" regulator-min-microvolt) == 1800000 ]]
[[ $(fdtget -t u "$arch_dtb" "$rsc_node/regulators-1/ldo6" regulator-max-microvolt) == 2960000 ]]
[[ $(fdtget -t s "$arch_dtb" "$rsc_node/regulators-1/ldo9" regulator-name) == vreg_l9c_2p96 ]]
[[ $(fdtget -t u "$arch_dtb" "$rsc_node/regulators-1/ldo9" regulator-min-microvolt) == 2704000 ]]
[[ $(fdtget -t u "$arch_dtb" "$rsc_node/regulators-1/ldo9" regulator-max-microvolt) == 2960000 ]]
[[ $(fdtget -t s "$arch_dtb" /soc@0/ufshc@1d84000 status) == disabled ]]
[[ $(fdtget -t s "$arch_dtb" /soc@0/gpu@3d00000 status) == disabled ]]
[[ $(fdtget -t s "$arch_dtb" /soc@0/display-subsystem@ae00000 status) == disabled ]]

tar -tzf "$artifact_dir/modules-$release.tar.gz" >"$module_list"
grep -q "^lib/modules/$release/kernel/drivers/net/wireless/ath/ath11k/ath11k_pci.ko" \
	"$module_list"
grep -q 'nt36523' "$module_list"

echo 'TB371FC Linux 7.1.8 release artifact verified (offline only).'
