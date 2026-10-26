#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Build a signed, one-shot direct reboot module for an exact V56.x kernel.
set -euo pipefail

PROJECT=${PROJECT:-<repo>}
BUILD_VERSION=${BUILD_VERSION:-56.3}
BUILD_SLUG=${BUILD_SLUG:-${BUILD_VERSION//./-}}
SOURCE=${SOURCE:-/root/tb371fc-desktop-v${BUILD_SLUG}-kexec-src}
OUTPUT=${OUTPUT:-/root/tb371fc-desktop-v${BUILD_SLUG}-kexec-out}
RELEASE=${RELEASE:-/root/tb371fc-desktop-v${BUILD_SLUG}-kexec-release}
MODULE_DIR=${MODULE_DIR:-/root/tb371fc-v${BUILD_SLUG}-emergency-bootloader-module}

for input in "$SOURCE/Makefile" "$OUTPUT/.config" "$OUTPUT/Module.symvers" \
	"$OUTPUT/scripts/sign-file" "$OUTPUT/certs/signing_key.pem" \
	"$OUTPUT/certs/signing_key.x509" \
	"$PROJECT/diagnostics/reboot-bootloader-emergency.c" \
	"$PROJECT/diagnostics/reboot-bootloader-emergency.Makefile"; do
	test -s "$input"
done

mkdir -p "$MODULE_DIR" "$RELEASE"
install -m0644 "$PROJECT/diagnostics/reboot-bootloader-emergency.c" \
	"$MODULE_DIR/reboot-bootloader-emergency.c"
install -m0644 "$PROJECT/diagnostics/reboot-bootloader-emergency.Makefile" \
	"$MODULE_DIR/Makefile"

export PATH=/root/snapdragon-clang-10.0.7/bin:/root/gcc-64/bin:/usr/bin:/bin
make -C "$SOURCE" O="$OUTPUT" ARCH=arm64 CC=clang \
	CLANG_TRIPLE=aarch64-linux-gnu- \
	CROSS_COMPILE=aarch64-linux-android- \
	M="$MODULE_DIR" modules

module=$RELEASE/reboot-bootloader-emergency.ko
install -m0644 "$MODULE_DIR/reboot-bootloader-emergency.ko" "$module"
/root/gcc-64/bin/aarch64-linux-android-strip --strip-debug "$module"
"$OUTPUT/scripts/sign-file" sha512 \
	"$OUTPUT/certs/signing_key.pem" "$OUTPUT/certs/signing_key.x509" "$module"

kernel_release=$(cat "$OUTPUT/include/config/kernel.release")
case "$kernel_release" in
	4.19.157-perf-v${BUILD_VERSION}*) ;;
	*) echo "Unexpected kernel release: $kernel_release" >&2; exit 2 ;;
esac
readelf -p .modinfo "$module" >"$RELEASE/reboot-bootloader-emergency.modinfo.txt"
grep -Fq "vermagic=$kernel_release " \
	"$RELEASE/reboot-bootloader-emergency.modinfo.txt"
tail -c 64 "$module" | grep -Fq '~Module signature appended~'
sha256sum "$module" >"$RELEASE/reboot-bootloader-emergency.SHA256"
sha256sum -c "$RELEASE/reboot-bootloader-emergency.SHA256"
