#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Build a V56.x kernel in isolated source/output trees. V55 remains immutable.
set -euo pipefail

PROJECT=${PROJECT:-$(cd "$(dirname "$0")/.." && pwd)}
BUILD_VERSION=${BUILD_VERSION:-56.1}
BUILD_SLUG=${BUILD_SLUG:-${BUILD_VERSION//./-}}
ENABLE_FHANDLE=${ENABLE_FHANDLE:-0}
ENABLE_KEXEC=${ENABLE_KEXEC:-0}
ENABLE_KEXEC_DRM_SHUTDOWN_WORKAROUND=${ENABLE_KEXEC_DRM_SHUTDOWN_WORKAROUND:-0}
ENABLE_KEXEC_CPU_HOTPLUG_WORKAROUND=${ENABLE_KEXEC_CPU_HOTPLUG_WORKAROUND:-0}
ENABLE_BT_HCIUART=${ENABLE_BT_HCIUART:-0}
ENABLE_DSI_LOGICAL_REFRESH_CLOCK=${ENABLE_DSI_LOGICAL_REFRESH_CLOCK:-0}
BASE_SOURCE=${BASE_SOURCE:-/root/tb371fc-desktop-working-kernel}
BASE_OUTPUT=${BASE_OUTPUT:-/root/tb371fc-desktop-working-out-v49}
VENDOR_SOURCE=${VENDOR_SOURCE:-/root/tb371fc-lenovo-4.19}
SOURCE=${SOURCE:-/root/tb371fc-desktop-v${BUILD_SLUG}-kde-wlan-safe-src}
OUTPUT=${OUTPUT:-/root/tb371fc-desktop-v${BUILD_SLUG}-kde-wlan-safe-out}
RELEASE=${RELEASE:-/root/tb371fc-desktop-v${BUILD_SLUG}-kde-wlan-safe-release}
NO_SSR_PATCH=$PROJECT/vendor-kernel/patches/0001-cnss2-add-no-ssr-diagnostic-mode.patch
SINGLE_QMI_PATCH=$PROJECT/vendor-kernel/patches/0002-cnss2-add-single-qmi-client-diagnostic-mode.patch
QCA_PATCH=$PROJECT/vendor-kernel/patches/0022-community-import-qcacld-build-glue.patch
QCA_COMPAT_PATCH=$PROJECT/vendor-kernel/patches/0023-community-backport-qcacld-netlink-time-helpers.patch
SDE_TEST_ONLY_PATCH=$PROJECT/vendor-kernel/patches/0024-community-drm-track-userspace-test-only.patch
KEXEC_PATCH=$PROJECT/vendor-kernel/patches/0015-arm64-avoid-legacy-cpu-soft-restart-kexec-name-clash.patch
KEXEC_DRM_SHUTDOWN_PATCH=$PROJECT/vendor-kernel/patches/0025-msm-drm-preserve-kms-state-during-kexec.patch
KEXEC_CPU_HOTPLUG_PATCH=$PROJECT/vendor-kernel/patches/0026-cpu-hotplug-ignore-suspend-wakeup-during-kexec.patch
DSI_LOGICAL_REFRESH_PATCH=$PROJECT/vendor-kernel/patches/0028-msm-dsi-export-logical-refresh-clock.patch
BUILD_LOG=${BUILD_LOG:-/root/tb371fc-v${BUILD_SLUG}-kernel-build.log}

toolchain_args=(
	ARCH=arm64
	CC=clang
	CLANG_TRIPLE=aarch64-linux-gnu-
	CROSS_COMPILE=aarch64-linux-android-
)

for input in "$BASE_SOURCE/.git" "$BASE_SOURCE/scripts/Kbuild.include" \
	"$BASE_OUTPUT/.config" "$VENDOR_SOURCE/drivers/staging/qcacld-3.0" \
	"$VENDOR_SOURCE/drivers/staging/qca-wifi-host-cmn" \
	"$VENDOR_SOURCE/drivers/staging/fw-api" "$NO_SSR_PATCH" \
	"$SINGLE_QMI_PATCH" "$QCA_PATCH" "$QCA_COMPAT_PATCH" \
	"$SDE_TEST_ONLY_PATCH" /root/snapdragon-clang-10.0.7/bin/clang; do
	test -e "$input" || { echo "Missing required input: $input" >&2; exit 2; }
done
if [ "$ENABLE_KEXEC" = 1 ]; then
	test -e "$KEXEC_PATCH" || {
		echo "Missing required kexec patch: $KEXEC_PATCH" >&2
		exit 2
	}
fi
if [ "$ENABLE_KEXEC_DRM_SHUTDOWN_WORKAROUND" = 1 ]; then
	test "$ENABLE_KEXEC" = 1 || {
		echo 'The DRM kexec shutdown workaround requires ENABLE_KEXEC=1' >&2
		exit 2
	}
	test -e "$KEXEC_DRM_SHUTDOWN_PATCH" || {
		echo "Missing DRM kexec shutdown patch: $KEXEC_DRM_SHUTDOWN_PATCH" >&2
		exit 2
	}
fi
if [ "$ENABLE_KEXEC_CPU_HOTPLUG_WORKAROUND" = 1 ]; then
	test "$ENABLE_KEXEC" = 1 || {
		echo 'The CPU-hotplug kexec workaround requires ENABLE_KEXEC=1' >&2
		exit 2
	}
	test -e "$KEXEC_CPU_HOTPLUG_PATCH" || {
		echo "Missing CPU-hotplug kexec patch: $KEXEC_CPU_HOTPLUG_PATCH" >&2
		exit 2
	}
fi
if [ "$ENABLE_DSI_LOGICAL_REFRESH_CLOCK" = 1 ]; then
	test -e "$DSI_LOGICAL_REFRESH_PATCH" || {
		echo "Missing DSI logical refresh patch: $DSI_LOGICAL_REFRESH_PATCH" >&2
		exit 2
	}
fi

export PATH=/root/snapdragon-clang-10.0.7/bin:/root/gcc-64/bin:/usr/bin:/bin

if [ ! -d "$SOURCE/.git" ]; then
	test ! -e "$SOURCE" || {
		echo "Refusing non-git source path: $SOURCE" >&2
		exit 3
	}
	git clone --shared --branch tb371fc-desktop-linux "$BASE_SOURCE" "$SOURCE"
	cp -a "$BASE_SOURCE/scripts/Kbuild.include" "$SOURCE/scripts/Kbuild.include"
	cp -a "$VENDOR_SOURCE/drivers/staging/qcacld-3.0" "$SOURCE/drivers/staging/"
	cp -a "$VENDOR_SOURCE/drivers/staging/qca-wifi-host-cmn" "$SOURCE/drivers/staging/"
	cp -a "$VENDOR_SOURCE/drivers/staging/fw-api" "$SOURCE/drivers/staging/"
fi

apply_once() {
	local marker=$1
	local file=$2
	local patch=$3
	if ! grep -Fq "$marker" "$SOURCE/$file"; then
		git -C "$SOURCE" apply --recount --check "$patch"
		git -C "$SOURCE" apply --recount "$patch"
	fi
}

apply_once 'config CNSS2_DIAGNOSTIC_NO_SSR' \
	drivers/net/wireless/cnss2/Kconfig "$NO_SSR_PATCH"
apply_once 'config CNSS2_DIAGNOSTIC_SINGLE_QMI_CLIENT' \
	drivers/net/wireless/cnss2/Kconfig "$SINGLE_QMI_PATCH"
apply_once 'source "drivers/staging/qcacld-3.0/Kconfig"' \
	drivers/staging/Kconfig "$QCA_PATCH"
apply_once 'static inline int nla_parse_deprecated' \
	include/net/netlink.h "$QCA_COMPAT_PATCH"
apply_once 'userspace_test_only' include/drm/drm_atomic.h \
	"$SDE_TEST_ONLY_PATCH"
if [ "$ENABLE_KEXEC" = 1 ]; then
	apply_once 'cpu_soft_restart_kexec' arch/arm64/kernel/cpu-reset.h \
		"$KEXEC_PATCH"
fi
if [ "$ENABLE_KEXEC_DRM_SHUTDOWN_WORKAROUND" = 1 ]; then
	apply_once 'preserving active KMS state' techpack/display/msm/msm_drv.c \
		"$KEXEC_DRM_SHUTDOWN_PATCH"
fi
if [ "$ENABLE_KEXEC_CPU_HOTPLUG_WORKAROUND" = 1 ]; then
	apply_once 'Kexec shutdown: ignoring suspend wakeup gate' kernel/cpu.c \
		"$KEXEC_CPU_HOTPLUG_PATCH"
fi
if [ "$ENABLE_DSI_LOGICAL_REFRESH_CLOCK" = 1 ]; then
	apply_once 'dsi_drm_logical_clock_khz' techpack/display/msm/dsi/dsi_drm.c \
		"$DSI_LOGICAL_REFRESH_PATCH"
fi

test -d "$SOURCE/drivers/staging/qcacld-3.0"
test -d "$SOURCE/drivers/staging/qca-wifi-host-cmn"
test -d "$SOURCE/drivers/staging/fw-api"
grep -Fq 'config CNSS2_DIAGNOSTIC_NO_SSR' \
	"$SOURCE/drivers/net/wireless/cnss2/Kconfig"
grep -Fq 'config CNSS2_DIAGNOSTIC_SINGLE_QMI_CLIENT' \
	"$SOURCE/drivers/net/wireless/cnss2/Kconfig"
grep -Fq 'userspace_test_only' "$SOURCE/techpack/display/msm/sde/sde_rm.c"

mkdir -p "$OUTPUT" "$RELEASE"
if [ ! -s "$OUTPUT/.config" ]; then
	cp "$BASE_OUTPUT/.config" "$OUTPUT/.config"
fi

config_args=(
	-e STAGING \
	-e CNSS_QCA6390 \
	-e CNSS2_DIAGNOSTIC_NO_SSR \
	-e CNSS2_DIAGNOSTIC_SINGLE_QMI_CLIENT \
	-m QCA_CLD_WLAN \
	--set-str QCA_CLD_WLAN_PROFILE qca6390 \
	--set-str LOCALVERSION "-perf-v${BUILD_VERSION}" \
	-d LOCALVERSION_AUTO
)
if [ "$ENABLE_FHANDLE" = 1 ]; then
	config_args+=( -e FHANDLE )
fi
if [ "$ENABLE_KEXEC" = 1 ]; then
	config_args+=( -e KEXEC )
fi
if [ "$ENABLE_BT_HCIUART" = 1 ]; then
	config_args+=(
		-e SERIAL_DEV_BUS
		-e BT_HCIUART
		-e BT_HCIUART_SERDEV
		-e BT_HCIUART_H4
		-e BT_HCIUART_QCA
		-e BT_QCA
	)
fi
"$SOURCE/scripts/config" --file "$OUTPUT/.config" "${config_args[@]}"

{
	echo "=== TB371FC V${BUILD_VERSION} kernel build $(date -Iseconds) ==="
	echo "base_commit=$(git -C "$BASE_SOURCE" rev-parse HEAD)"
	echo "source=$SOURCE"
	echo "output=$OUTPUT"
	clang --version | head -2
	make -C "$SOURCE" O="$OUTPUT" "${toolchain_args[@]}" olddefconfig
	grep -E '^(CONFIG_(LOCALVERSION|FHANDLE|KEXEC|KEXEC_CORE|CNSS_QCA6390|CNSS2_DIAGNOSTIC_NO_SSR|CNSS2_DIAGNOSTIC_SINGLE_QMI_CLIENT|QCA_CLD_WLAN|QCA_CLD_WLAN_PROFILE)=)' \
		"$OUTPUT/.config"
	make -C "$SOURCE" O="$OUTPUT" "${toolchain_args[@]}" \
		-j"$(nproc)" Image modules
} 2>&1 | tee "$BUILD_LOG"

kernel=$OUTPUT/arch/arm64/boot/Image
module=$OUTPUT/drivers/staging/qcacld-3.0/wlan.ko
test -s "$kernel"
test -s "$module"
kernel_release=$(cat "$OUTPUT/include/config/kernel.release")
case "$kernel_release" in
	4.19.157-perf-v${BUILD_VERSION}*) ;;
	*) echo "Unexpected V${BUILD_VERSION} kernel release: $kernel_release" >&2; exit 4 ;;
esac

install -m0644 "$kernel" "$RELEASE/Image"
install -m0644 "$module" "$RELEASE/wlan.ko"
/root/gcc-64/bin/aarch64-linux-android-strip --strip-debug \
	"$RELEASE/wlan.ko"
"$OUTPUT/scripts/sign-file" sha512 \
	"$OUTPUT/certs/signing_key.pem" "$OUTPUT/certs/signing_key.x509" \
	"$RELEASE/wlan.ko"
install -m0644 "$OUTPUT/.config" "$RELEASE/kernel.config"
install -m0644 "$OUTPUT/Module.symvers" "$RELEASE/Module.symvers"
printf '%s\n' "$kernel_release" >"$RELEASE/kernel.release"
{
	echo "kernel_release=$kernel_release"
	echo "base_commit=$(git -C "$BASE_SOURCE" rev-parse HEAD)"
	echo 'safety=CNSS2_NO_SSR+SINGLE_QMI'
	echo 'display=DRM_USERSPACE_TEST_ONLY_TRACKING'
	echo "kexec=$ENABLE_KEXEC"
	echo "kexec_drm_shutdown_workaround=$ENABLE_KEXEC_DRM_SHUTDOWN_WORKAROUND"
	echo "kexec_cpu_hotplug_workaround=$ENABLE_KEXEC_CPU_HOTPLUG_WORKAROUND"
	echo "bt_hci_uart_qca=$ENABLE_BT_HCIUART"
	echo "dsi_logical_refresh_clock=$ENABLE_DSI_LOGICAL_REFRESH_CLOCK"
	echo "v${BUILD_SLUG}_source_status_begin"
	git -C "$SOURCE" status --short
	echo "v${BUILD_SLUG}_source_status_end"
} >"$RELEASE/BUILD-METADATA.txt"

readelf -p .modinfo "$RELEASE/wlan.ko" >"$RELEASE/wlan.modinfo.txt"
grep -Fq "vermagic=$kernel_release " "$RELEASE/wlan.modinfo.txt"
tail -c 64 "$RELEASE/wlan.ko" | grep -Fq '~Module signature appended~'
grep -Fqx 'CONFIG_CNSS2_DIAGNOSTIC_NO_SSR=y' "$RELEASE/kernel.config"
grep -Fqx 'CONFIG_CNSS2_DIAGNOSTIC_SINGLE_QMI_CLIENT=y' \
	"$RELEASE/kernel.config"
if [ "$ENABLE_FHANDLE" = 1 ]; then
	grep -Fqx 'CONFIG_FHANDLE=y' "$RELEASE/kernel.config"
fi
if [ "$ENABLE_KEXEC" = 1 ]; then
	grep -Fqx 'CONFIG_KEXEC=y' "$RELEASE/kernel.config"
	grep -Fqx 'CONFIG_KEXEC_CORE=y' "$RELEASE/kernel.config"
fi
if [ "$ENABLE_KEXEC_DRM_SHUTDOWN_WORKAROUND" = 1 ]; then
	grep -Fq 'if (kexec_in_progress)' \
		"$SOURCE/techpack/display/msm/msm_drv.c"
	grep -Fq 'skipping unsafe lastclose' \
		"$SOURCE/techpack/display/msm/msm_drv.c"
fi
if [ "$ENABLE_KEXEC_CPU_HOTPLUG_WORKAROUND" = 1 ]; then
	grep -Fq '!kexec_in_progress && pm_wakeup_pending()' \
		"$SOURCE/kernel/cpu.c"
	grep -Fq 'Kexec shutdown: ignoring suspend wakeup gate' \
		"$SOURCE/kernel/cpu.c"
fi
if [ "$ENABLE_BT_HCIUART" = 1 ]; then
	grep -Fqx 'CONFIG_SERIAL_DEV_BUS=y' "$RELEASE/kernel.config"
	grep -Fqx 'CONFIG_BT_HCIUART=y' "$RELEASE/kernel.config"
	grep -Fqx 'CONFIG_BT_HCIUART_SERDEV=y' "$RELEASE/kernel.config"
	grep -Fqx 'CONFIG_BT_HCIUART_H4=y' "$RELEASE/kernel.config"
	grep -Fqx 'CONFIG_BT_HCIUART_QCA=y' "$RELEASE/kernel.config"
	grep -Fqx 'CONFIG_BT_QCA=y' "$RELEASE/kernel.config"
fi
if [ "$ENABLE_DSI_LOGICAL_REFRESH_CLOCK" = 1 ]; then
	grep -Fq 'dsi_drm_logical_clock_khz' \
		"$SOURCE/techpack/display/msm/dsi/dsi_drm.c"
	grep -Fq 'dsi_display_logical_clock_khz' \
		"$SOURCE/techpack/display/msm/dsi/dsi_display.c"
fi
sha256sum "$RELEASE/Image" "$RELEASE/wlan.ko" "$RELEASE/kernel.config" \
	"$RELEASE/Module.symvers" >"$RELEASE/SHA256SUMS"
sha256sum -c "$RELEASE/SHA256SUMS"

echo "V${BUILD_VERSION} kernel release ready: $kernel_release"
echo "Release directory: $RELEASE"
