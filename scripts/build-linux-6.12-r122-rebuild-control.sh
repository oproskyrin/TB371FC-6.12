#!/usr/bin/env bash
# Rebuild the NOP-checkpoint source with EXACT r70/r68 configuration.
# Source is read-only; all generated files go into a new output directory.
set -euo pipefail
src=/root/tb371fc/linux-6.12-donor-r118
baseline=/root/tb371fc/build-6.12-r68-memblock-checkpoint
out=/root/tb371fc/build-6.12-r122-rebuild-control
pkg=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r122-rebuild-control
test ! -e "$out"
test ! -e "$pkg"
test -s "$src/arch/arm64/kernel/setup.c"
printf '%s  %s\n' 373f4d9bfe65f55324a60e835e10459bd7956df71b595fea9f767c48683be3cd "$baseline/.config" | sha256sum -c -
if grep -Fq '"smc #0\n"' "$src/arch/arm64/kernel/setup.c"; then
    echo 'Refusing source with diagnostic SMC still enabled' >&2
    exit 1
fi
grep -Fq '"nop\n"' "$src/arch/arm64/kernel/setup.c"
mkdir "$out" "$pkg"
cp "$baseline/.config" "$out/.config"
export KBUILD_BUILD_USER=root KBUILD_BUILD_HOST=builder KBUILD_BUILD_VERSION=1
# Preserve the reference timestamp as well as localversion to minimize drift.
export KBUILD_BUILD_TIMESTAMP
KBUILD_BUILD_TIMESTAMP=$(sed -n 's/^#define UTS_VERSION "#1 SMP PREEMPT \(.*\)"$/\1/p' "$baseline/include/generated/utsversion.h")
test -n "$KBUILD_BUILD_TIMESTAMP"
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 olddefconfig >"$pkg/configure.log" 2>&1
cmp "$baseline/.config" "$out/.config"
git -C "$src" diff --binary >"$pkg/source.patch"
git -C "$src" rev-parse HEAD >"$pkg/source-commit.txt"
sha256sum "$src/arch/arm64/kernel/setup.c" >"$pkg/setup-source-before.sha256"
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 -j8 Image >"$pkg/compile.log" 2>&1
sha256sum -c "$pkg/setup-source-before.sha256"
cmp "$baseline/.config" "$out/.config"
cp "$out/arch/arm64/boot/Image" "$out/System.map" "$out/.config" "$pkg/"
cp "$out/include/generated/utsrelease.h" "$out/include/generated/utsversion.h" "$pkg/"
(cd "$pkg"; sha256sum Image System.map .config source.patch >SHA256SUMS)
printf 'R122 rebuilt control; same config and version label as r70; NOT hardware tested.\n'
sha256sum "$pkg/Image"
