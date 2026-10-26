#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KERNEL_DIR="${KERNEL_DIR:-$HOME/tb371fc-linux-7.1}"
OUT_DIR="${OUT_DIR:-$HOME/tb371fc-linux-7.1-out}"
JOBS="${JOBS:-$(nproc)}"
STABLE_URL="https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git"
STABLE_BRANCH="linux-7.1.y"
DTS_NAME="sm8250-lenovo-tb371fc"
STAGE0_DTS_NAME="sm8250-lenovo-tb371fc-stage0"
ARCH_TEST_DTS_NAME="sm8250-lenovo-tb371fc-arch-test"
TOUCH_TEST_DTS_NAME="sm8250-lenovo-tb371fc-touch-test"
DISPLAY_TEST_DTS_NAME="sm8250-lenovo-tb371fc-display-test"
CAMERA_TEST_DTS_NAME="sm8250-lenovo-tb371fc-gc08a3-test"
S5K4H7_TEST_DTS_NAME="sm8250-lenovo-tb371fc-s5k4h7-test"

if [[ ! -e "$KERNEL_DIR/.git" ]]; then
	git clone --depth=1 --branch "$STABLE_BRANCH" "$STABLE_URL" "$KERNEL_DIR"
fi

for required_source in Makefile Kconfig scripts/Makefile.build arch/arm64/Makefile; do
	if [[ ! -f "$KERNEL_DIR/$required_source" ]]; then
		echo "Kernel worktree is incomplete: missing $KERNEL_DIR/$required_source" >&2
		echo "Choose a new empty KERNEL_DIR; existing trees are never repaired automatically." >&2
		exit 1
	fi
done

mkdir -p "$OUT_DIR"
install -m 0644 \
	"$PROJECT_DIR/mainline-port/arch/arm64/boot/dts/qcom/$DTS_NAME.dts" \
	"$KERNEL_DIR/arch/arm64/boot/dts/qcom/$DTS_NAME.dts"
install -m 0644 \
	"$PROJECT_DIR/mainline-port/arch/arm64/boot/dts/qcom/$STAGE0_DTS_NAME.dts" \
	"$KERNEL_DIR/arch/arm64/boot/dts/qcom/$STAGE0_DTS_NAME.dts"
install -m 0644 \
	"$PROJECT_DIR/mainline-port/arch/arm64/boot/dts/qcom/$ARCH_TEST_DTS_NAME.dts" \
	"$KERNEL_DIR/arch/arm64/boot/dts/qcom/$ARCH_TEST_DTS_NAME.dts"
install -m 0644 \
	"$PROJECT_DIR/mainline-port/arch/arm64/boot/dts/qcom/$TOUCH_TEST_DTS_NAME.dts" \
	"$KERNEL_DIR/arch/arm64/boot/dts/qcom/$TOUCH_TEST_DTS_NAME.dts"
install -m 0644 \
	"$PROJECT_DIR/mainline-port/arch/arm64/boot/dts/qcom/$DISPLAY_TEST_DTS_NAME.dts" \
	"$KERNEL_DIR/arch/arm64/boot/dts/qcom/$DISPLAY_TEST_DTS_NAME.dts"
install -m 0644 \
	"$PROJECT_DIR/mainline-port/arch/arm64/boot/dts/qcom/$CAMERA_TEST_DTS_NAME.dts" \
	"$KERNEL_DIR/arch/arm64/boot/dts/qcom/$CAMERA_TEST_DTS_NAME.dts"
install -m 0644 \
	"$PROJECT_DIR/mainline-port/arch/arm64/boot/dts/qcom/$S5K4H7_TEST_DTS_NAME.dts" \
	"$KERNEL_DIR/arch/arm64/boot/dts/qcom/$S5K4H7_TEST_DTS_NAME.dts"
install -m 0644 \
	"$PROJECT_DIR/mainline-port/drivers/media/i2c/s5k4h7.c" \
	"$KERNEL_DIR/drivers/media/i2c/s5k4h7.c"
install -m 0644 \
	"$PROJECT_DIR/mainline-port/drivers/video/backlight/tb371fc-ktz8866.c" \
	"$KERNEL_DIR/drivers/video/backlight/tb371fc-ktz8866.c"
install -m 0644 \
	"$PROJECT_DIR/mainline-port/Documentation/devicetree/bindings/media/i2c/samsung,s5k4h7.yaml" \
	"$KERNEL_DIR/Documentation/devicetree/bindings/media/i2c/samsung,s5k4h7.yaml"
install -m 0644 \
	"$PROJECT_DIR/mainline-port/Documentation/devicetree/bindings/leds/backlight/lenovo,tb371fc-ktz8866.yaml" \
	"$KERNEL_DIR/Documentation/devicetree/bindings/leds/backlight/lenovo,tb371fc-ktz8866.yaml"

PATCH_STATE_DIR="$KERNEL_DIR/.tb371fc-patch-state"
mkdir -p "$PATCH_STATE_DIR"
for kernel_patch in "$PROJECT_DIR"/mainline-port/patches/*.patch; do
	[[ -e "$kernel_patch" ]] || continue
	patch_hash=$(sha256sum "$kernel_patch" | awk '{print $1}')
	patch_marker="$PATCH_STATE_DIR/$(basename "$kernel_patch").$patch_hash"
	if [[ -f "$patch_marker" ]]; then
		continue
	fi
	if git -C "$KERNEL_DIR" apply --recount --reverse --check "$kernel_patch" 2>/dev/null; then
		touch "$patch_marker"
		continue
	fi
	git -C "$KERNEL_DIR" apply --recount --check "$kernel_patch"
	git -C "$KERNEL_DIR" apply --recount "$kernel_patch"
	touch "$patch_marker"
done

if ! grep -q "${DTS_NAME}.dtb" "$KERNEL_DIR/arch/arm64/boot/dts/qcom/Makefile"; then
	sed -i "/sm8250-hdk.dtb/a dtb-\$(CONFIG_ARCH_QCOM)\t+= ${DTS_NAME}.dtb" \
		"$KERNEL_DIR/arch/arm64/boot/dts/qcom/Makefile"
fi
if ! grep -q "${STAGE0_DTS_NAME}.dtb" "$KERNEL_DIR/arch/arm64/boot/dts/qcom/Makefile"; then
	sed -i "/${DTS_NAME}.dtb/a dtb-\$(CONFIG_ARCH_QCOM)\t+= ${STAGE0_DTS_NAME}.dtb" \
		"$KERNEL_DIR/arch/arm64/boot/dts/qcom/Makefile"
fi
if ! grep -q "${ARCH_TEST_DTS_NAME}.dtb" "$KERNEL_DIR/arch/arm64/boot/dts/qcom/Makefile"; then
	sed -i "/${STAGE0_DTS_NAME}.dtb/a dtb-\$(CONFIG_ARCH_QCOM)\t+= ${ARCH_TEST_DTS_NAME}.dtb" \
		"$KERNEL_DIR/arch/arm64/boot/dts/qcom/Makefile"
fi
if ! grep -q "${TOUCH_TEST_DTS_NAME}.dtb" "$KERNEL_DIR/arch/arm64/boot/dts/qcom/Makefile"; then
	sed -i "/${DTS_NAME}.dtb/a dtb-\$(CONFIG_ARCH_QCOM)\t+= ${TOUCH_TEST_DTS_NAME}.dtb" \
		"$KERNEL_DIR/arch/arm64/boot/dts/qcom/Makefile"
fi
if ! grep -q "${DISPLAY_TEST_DTS_NAME}.dtb" "$KERNEL_DIR/arch/arm64/boot/dts/qcom/Makefile"; then
	sed -i "/${TOUCH_TEST_DTS_NAME}.dtb/a dtb-\$(CONFIG_ARCH_QCOM)\t+= ${DISPLAY_TEST_DTS_NAME}.dtb" \
		"$KERNEL_DIR/arch/arm64/boot/dts/qcom/Makefile"
fi
if ! grep -q "${CAMERA_TEST_DTS_NAME}.dtb" "$KERNEL_DIR/arch/arm64/boot/dts/qcom/Makefile"; then
	sed -i "/${DTS_NAME}.dtb/a dtb-\$(CONFIG_ARCH_QCOM)\t+= ${CAMERA_TEST_DTS_NAME}.dtb" \
		"$KERNEL_DIR/arch/arm64/boot/dts/qcom/Makefile"
fi
if ! grep -q "${S5K4H7_TEST_DTS_NAME}.dtb" "$KERNEL_DIR/arch/arm64/boot/dts/qcom/Makefile"; then
	sed -i "/${CAMERA_TEST_DTS_NAME}.dtb/a dtb-\$(CONFIG_ARCH_QCOM)\t+= ${S5K4H7_TEST_DTS_NAME}.dtb" \
		"$KERNEL_DIR/arch/arm64/boot/dts/qcom/Makefile"
fi
make -C "$KERNEL_DIR" O="$OUT_DIR" ARCH=arm64 \
	CROSS_COMPILE=aarch64-linux-gnu- defconfig

CONFIG_FRAGMENT="$OUT_DIR/tb371fc-arch.config"
install -m 0644 "$PROJECT_DIR/mainline-port/tb371fc-arch.config" "$CONFIG_FRAGMENT"
"$KERNEL_DIR/scripts/kconfig/merge_config.sh" -m -O "$OUT_DIR" \
	"$OUT_DIR/.config" "$CONFIG_FRAGMENT"

make -C "$KERNEL_DIR" O="$OUT_DIR" ARCH=arm64 \
	CROSS_COMPILE=aarch64-linux-gnu- olddefconfig

if [[ -n ${BUILD_TARGETS:-} ]]; then
	read -r -a build_targets <<< "$BUILD_TARGETS"
else
	build_targets=(
		Image
		"qcom/${DTS_NAME}.dtb"
		"qcom/${STAGE0_DTS_NAME}.dtb"
		"qcom/${ARCH_TEST_DTS_NAME}.dtb"
		"qcom/${TOUCH_TEST_DTS_NAME}.dtb"
		"qcom/${DISPLAY_TEST_DTS_NAME}.dtb"
		"qcom/${CAMERA_TEST_DTS_NAME}.dtb"
		"qcom/${S5K4H7_TEST_DTS_NAME}.dtb"
		modules
	)
fi

make -C "$KERNEL_DIR" O="$OUT_DIR" ARCH=arm64 \
	CROSS_COMPILE=aarch64-linux-gnu- LOCALVERSION= \
	-j"$JOBS" "${build_targets[@]}"

if [[ -n ${MODULES_INSTALL_DIR:-} ]]; then
	mkdir -p "$MODULES_INSTALL_DIR"
	make -C "$KERNEL_DIR" O="$OUT_DIR" ARCH=arm64 \
		CROSS_COMPILE=aarch64-linux-gnu- \
		LOCALVERSION= \
		INSTALL_MOD_STRIP=1 \
		INSTALL_MOD_PATH="$MODULES_INSTALL_DIR" modules_install
fi

printf 'Kernel: %s\n' "$OUT_DIR/arch/arm64/boot/Image"
printf 'DTB:    %s\n' "$OUT_DIR/arch/arm64/boot/dts/qcom/${DTS_NAME}.dtb"
printf 'Stage0: %s\n' "$OUT_DIR/arch/arm64/boot/dts/qcom/${STAGE0_DTS_NAME}.dtb"
printf 'Arch:   %s\n' "$OUT_DIR/arch/arm64/boot/dts/qcom/${ARCH_TEST_DTS_NAME}.dtb"
printf 'Touch:  %s\n' "$OUT_DIR/arch/arm64/boot/dts/qcom/${TOUCH_TEST_DTS_NAME}.dtb"
printf 'Display:%s\n' "$OUT_DIR/arch/arm64/boot/dts/qcom/${DISPLAY_TEST_DTS_NAME}.dtb"
printf 'Camera: %s\n' "$OUT_DIR/arch/arm64/boot/dts/qcom/${CAMERA_TEST_DTS_NAME}.dtb"
printf 'S5K4H7: %s\n' "$OUT_DIR/arch/arm64/boot/dts/qcom/${S5K4H7_TEST_DTS_NAME}.dtb"
