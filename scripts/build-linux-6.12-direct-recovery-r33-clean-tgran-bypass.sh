#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
kernel_dir=/root/tb371fc/linux-6.12-donor
out_dir=/root/tb371fc/build-6.12-mmu-diag
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-clean-tgran-bypass-r33
output=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-direct-recovery-r33-clean-tgran-bypass
tgran_patch="$project/mainline-port/patches/0026-arm64-tb371fc-bypass-broken-tgran-read-without-fb-markers.patch"

test -d "$kernel_dir/.git"
test -f "$out_dir/.config"
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }
test ! -e "$output" || { echo "Refusing to overwrite $output" >&2; exit 1; }

if git -C "$kernel_dir" apply --check "$tgran_patch" 2>/dev/null; then
	git -C "$kernel_dir" apply "$tgran_patch"
elif ! git -C "$kernel_dir" apply --reverse --check "$tgran_patch" 2>/dev/null; then
	echo 'TGran bypass patch is neither applicable nor already applied' >&2
	exit 1
fi

"$kernel_dir/scripts/config" --file "$out_dir/.config" --disable TB371FC_EARLY_FB_MARKER
make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 olddefconfig
grep -qx '# CONFIG_TB371FC_EARLY_FB_MARKER is not set' "$out_dir/.config"
grep -A16 'SYM_FUNC_START(__enable_mmu)' "$kernel_dir/arch/arm64/kernel/head.S" | grep -q 'mov.*x3, xzr'

make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 -j"$(nproc)" Image

mkdir -p "$package"
install -m0644 "$out_dir/arch/arm64/boot/Image" "$package/Image"
install -m0644 "$out_dir/.config" "$package/config"
install -m0644 "$out_dir/System.map" "$package/System.map"
{
	echo 'TB371FC Linux 6.12 r33 clean boot with independent TGran bypass'
	echo 'Physical framebuffer diagnostics disabled'
	echo 'Upstream early_init_stack flow retained'
	echo 'Known-failing ABL ID_AA64MMFR0_EL1 TGran read bypassed'
	sha256sum "$package/Image" "$package/config" "$package/System.map"
} >"$package/BUILD-INFO.txt"

export PACKAGE="$package"
export OUTPUT="$output"
export BUILD_LABEL='r33 source-built; clean post-MMU path plus proven TGran bypass'
export LINUX_BASE=0xa4000000
export EXTRA_CFLAGS='-DCORRECT_CACHE_HANDOFF=1 -DSKIP_EL_DIAGNOSTIC=1'
export CMDLINE_EXTRA='maxcpus=1 earlycon keep_bootcon ignore_loglevel loglevel=8'

exec "$project/scripts/build-linux-6.12-direct-recovery-r17-proven-v56-wrapper.sh"
