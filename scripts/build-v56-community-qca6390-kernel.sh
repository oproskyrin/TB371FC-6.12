#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Build the V56 downstream kernel without modifying the proven V55 source/output.
set -euo pipefail

PROJECT=${PROJECT:-$(cd "$(dirname "$0")/.." && pwd)}
BASE_SOURCE=${BASE_SOURCE:-/root/tb371fc-desktop-working-kernel}
BASE_OUTPUT=${BASE_OUTPUT:-/root/tb371fc-desktop-working-out-v49}
VENDOR_SOURCE=${VENDOR_SOURCE:-/root/tb371fc-lenovo-4.19}
SOURCE=${SOURCE:-/root/tb371fc-desktop-v56-kde-wlan-src}
OUTPUT=${OUTPUT:-/root/tb371fc-desktop-v56-kde-wlan-out}
RELEASE=${RELEASE:-/root/tb371fc-desktop-v56-kde-wlan-release}
PATCH=$PROJECT/vendor-kernel/patches/0022-community-import-qcacld-build-glue.patch
COMPAT_PATCH=$PROJECT/vendor-kernel/patches/0023-community-backport-qcacld-netlink-time-helpers.patch
BUILD_LOG=${BUILD_LOG:-/root/tb371fc-v56-kernel-build.log}

toolchain_args=(
	ARCH=arm64
	CC=clang
	CLANG_TRIPLE=aarch64-linux-gnu-
	CROSS_COMPILE=aarch64-linux-android-
)

for input in "$BASE_SOURCE/.git" "$BASE_SOURCE/scripts/Kbuild.include" \
	"$BASE_OUTPUT/.config" "$VENDOR_SOURCE/drivers/staging/qcacld-3.0" \
	"$VENDOR_SOURCE/drivers/staging/qca-wifi-host-cmn" \
	"$VENDOR_SOURCE/drivers/staging/fw-api" "$PATCH" "$COMPAT_PATCH" \
	/root/snapdragon-clang-10.0.7/bin/clang; do
	test -e "$input" || { echo "Missing required input: $input" >&2; exit 2; }
done

export PATH=/root/snapdragon-clang-10.0.7/bin:/root/gcc-64/bin:/usr/bin:/bin

if [ ! -d "$SOURCE/.git" ]; then
	test ! -e "$SOURCE" || { echo "Refusing non-git source path: $SOURCE" >&2; exit 3; }
	git clone --shared --branch tb371fc-desktop-linux "$BASE_SOURCE" "$SOURCE"
	cp -a "$BASE_SOURCE/scripts/Kbuild.include" "$SOURCE/scripts/Kbuild.include"
	cp -a "$VENDOR_SOURCE/drivers/staging/qcacld-3.0" "$SOURCE/drivers/staging/"
	cp -a "$VENDOR_SOURCE/drivers/staging/qca-wifi-host-cmn" "$SOURCE/drivers/staging/"
	cp -a "$VENDOR_SOURCE/drivers/staging/fw-api" "$SOURCE/drivers/staging/"

fi
if ! grep -Fq 'source "drivers/staging/qcacld-3.0/Kconfig"' \
	"$SOURCE/drivers/staging/Kconfig"; then
	git -C "$SOURCE" apply --check "$PATCH"
	git -C "$SOURCE" apply "$PATCH"
fi
if ! grep -Fq 'static inline int nla_parse_deprecated' \
	"$SOURCE/include/net/netlink.h"; then
	git -C "$SOURCE" apply --check "$COMPAT_PATCH"
	git -C "$SOURCE" apply "$COMPAT_PATCH"
fi

test -d "$SOURCE/drivers/staging/qcacld-3.0"
test -d "$SOURCE/drivers/staging/qca-wifi-host-cmn"
test -d "$SOURCE/drivers/staging/fw-api"
grep -Fq 'source "drivers/staging/qcacld-3.0/Kconfig"' "$SOURCE/drivers/staging/Kconfig"
grep -Fq 'obj-$(CONFIG_QCA_CLD_WLAN)' "$SOURCE/drivers/staging/Makefile"

mkdir -p "$OUTPUT" "$RELEASE"
if [ ! -s "$OUTPUT/.config" ]; then
	cp "$BASE_OUTPUT/.config" "$OUTPUT/.config"
fi

"$SOURCE/scripts/config" --file "$OUTPUT/.config" \
	-e STAGING \
	-e CNSS_QCA6390 \
	-m QCA_CLD_WLAN \
	--set-str QCA_CLD_WLAN_PROFILE qca6390 \
	--set-str LOCALVERSION -perf-v56 \
	-d LOCALVERSION_AUTO

{
	echo "=== TB371FC V56 kernel build $(date -Iseconds) ==="
	echo "base_commit=$(git -C "$BASE_SOURCE" rev-parse HEAD)"
	echo "source=$SOURCE"
	echo "output=$OUTPUT"
	clang --version | head -2
	make -C "$SOURCE" O="$OUTPUT" "${toolchain_args[@]}" olddefconfig
	grep -E '^(CONFIG_(LOCALVERSION|CNSS_QCA6390|QCA_CLD_WLAN|QCA_CLD_WLAN_PROFILE)=)' \
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
	4.19.157-perf-v56*) ;;
	*) echo "Unexpected V56 kernel release: $kernel_release" >&2; exit 4 ;;
esac

install -m0644 "$kernel" "$RELEASE/Image"
install -m0644 "$module" "$RELEASE/wlan.ko"
# CONFIG_DEBUG_INFO is retained for the kernel build diagnostics, but carrying
# 280+ MiB of DWARF in recovery is unnecessary. Strip only debug sections and
# append a fresh signature from the exact key embedded in this V56 kernel.
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
	echo "v56_source_status_begin"
	git -C "$SOURCE" status --short
	echo "v56_source_status_end"
} >"$RELEASE/BUILD-METADATA.txt"

readelf -p .modinfo "$RELEASE/wlan.ko" >"$RELEASE/wlan.modinfo.txt"
grep -Fq "vermagic=$kernel_release " "$RELEASE/wlan.modinfo.txt"
tail -c 64 "$RELEASE/wlan.ko" | grep -Fq '~Module signature appended~'
sha256sum "$RELEASE/Image" "$RELEASE/wlan.ko" "$RELEASE/kernel.config" \
	"$RELEASE/Module.symvers" >"$RELEASE/SHA256SUMS"
sha256sum -c "$RELEASE/SHA256SUMS"

echo "V56 kernel release ready: $kernel_release"
echo "Release directory: $RELEASE"
