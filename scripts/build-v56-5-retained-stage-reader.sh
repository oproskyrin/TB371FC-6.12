#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

PROJECT=${PROJECT:-<repo>}
SOURCE=${SOURCE:-/root/tb371fc-desktop-v56-5-kexec-cpu-hotplug-src}
OUTPUT=${OUTPUT:-/root/tb371fc-desktop-v56-5-kexec-cpu-hotplug-out}
RELEASE=${RELEASE:-/root/tb371fc-v56-5-retained-stage-reader-release}
MODULE_DIR=${MODULE_DIR:-/root/tb371fc-v56-5-retained-stage-reader-module}

for input in "$SOURCE/Makefile" "$OUTPUT/.config" "$OUTPUT/Module.symvers" \
	"$OUTPUT/scripts/sign-file" "$OUTPUT/certs/signing_key.pem" \
	"$OUTPUT/certs/signing_key.x509" \
	"$PROJECT/diagnostics/tb371fc-retained-stage-reader.c" \
	"$PROJECT/diagnostics/tb371fc-retained-stage-reader.Makefile"; do
	test -s "$input"
done

mkdir -p "$MODULE_DIR" "$RELEASE"
install -m0644 "$PROJECT/diagnostics/tb371fc-retained-stage-reader.c" \
	"$MODULE_DIR/tb371fc-retained-stage-reader.c"
install -m0644 "$PROJECT/diagnostics/tb371fc-retained-stage-reader.Makefile" \
	"$MODULE_DIR/Makefile"

export PATH=/root/snapdragon-clang-10.0.7/bin:/root/gcc-64/bin:/usr/bin:/bin
make -C "$SOURCE" O="$OUTPUT" ARCH=arm64 CC=clang \
	CLANG_TRIPLE=aarch64-linux-gnu- CROSS_COMPILE=aarch64-linux-android- \
	M="$MODULE_DIR" modules

module=$RELEASE/tb371fc-retained-stage-reader.ko
install -m0644 "$MODULE_DIR/tb371fc-retained-stage-reader.ko" "$module"
/root/gcc-64/bin/aarch64-linux-android-strip --strip-debug "$module"
"$OUTPUT/scripts/sign-file" sha512 "$OUTPUT/certs/signing_key.pem" \
	"$OUTPUT/certs/signing_key.x509" "$module"

kernel_release=$(cat "$OUTPUT/include/config/kernel.release")
case "$kernel_release" in
	4.19.157-perf-v56.5*) ;;
	*) echo "Unexpected kernel release: $kernel_release" >&2; exit 2 ;;
esac
readelf -p .modinfo "$module" >"$RELEASE/tb371fc-retained-stage-reader.modinfo.txt"
grep -Fq "vermagic=$kernel_release " "$RELEASE/tb371fc-retained-stage-reader.modinfo.txt"
tail -c 64 "$module" | grep -Fq '~Module signature appended~'
sha256sum "$module" >"$RELEASE/tb371fc-retained-stage-reader.SHA256"
sha256sum -c "$RELEASE/tb371fc-retained-stage-reader.SHA256"
