#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
kernel_dir=/root/tb371fc/linux-6.12-donor
out_dir=/root/tb371fc/build-6.12-mmu-diag
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-safe-post-mmu-r28
output=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-direct-recovery-r28-safe-post-mmu
patch_file="$project/mainline-port/patches/0022-arm64-tb371fc-remove-unsafe-post-mmu-stage-words.patch"

test -d "$kernel_dir/.git"
test -f "$out_dir/.config"
grep -qx 'CONFIG_TB371FC_EARLY_FB_MARKER=y' "$out_dir/.config"
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }
test ! -e "$output" || { echo "Refusing to overwrite $output" >&2; exit 1; }

if git -C "$kernel_dir" apply --reverse --check "$patch_file" 2>/dev/null; then
	echo 'r28 source patch already applied'
else
	git -C "$kernel_dir" apply --check "$patch_file"
	git -C "$kernel_dir" apply "$patch_file"
fi

make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 -j"$(nproc)" Image

mkdir -p "$package"
install -m0644 "$out_dir/arch/arm64/boot/Image" "$package/Image"
install -m0644 "$out_dir/.config" "$package/config"
install -m0644 "$out_dir/System.map" "$package/System.map"
{
	echo 'TB371FC Linux 6.12 r28 safe post-MMU continuation'
	echo 'r27 proved MMU-on and return; unsafe physical stage-word writes removed'
	echo 'maxcpus=1 prevents secondary CPU marker overwrite'
	sha256sum "$package/Image" "$package/config" "$package/System.map"
} >"$package/BUILD-INFO.txt"

export PACKAGE="$package"
export OUTPUT="$output"
export BUILD_LABEL='r28 source-built; MMU proven; unsafe post-MMU stage words removed'
export LINUX_BASE=0xa4000000
export EXTRA_CFLAGS='-DCORRECT_CACHE_HANDOFF=1 -DSKIP_EL_DIAGNOSTIC=1'
export CMDLINE_EXTRA='maxcpus=1'

exec "$project/scripts/build-linux-6.12-direct-recovery-r17-proven-v56-wrapper.sh"
