#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
kernel_dir=/root/tb371fc/linux-6.12-donor
out_dir=/root/tb371fc/build-6.12-mmu-diag
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-physical-early-stack-r31
output=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-direct-recovery-r31-physical-early-stack
patch_file="$project/mainline-port/patches/0025-arm64-tb371fc-use-physical-early-stack-before-final-map.patch"

test -d "$kernel_dir/.git"
test -f "$out_dir/.config"
grep -qx 'CONFIG_TB371FC_EARLY_FB_MARKER=y' "$out_dir/.config"
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }
test ! -e "$output" || { echo "Refusing to overwrite $output" >&2; exit 1; }

if git -C "$kernel_dir" apply --reverse --check "$patch_file" 2>/dev/null; then
	echo 'r31 source patch already applied'
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
	echo 'TB371FC Linux 6.12 r31 physical early stack'
	echo 'Use early_init_stack physical address under TTBR0 before final mapping'
	echo 'red=MMU returned; green=before early_map; blue=early_map returned; yellow=primary_switched'
	sha256sum "$package/Image" "$package/config" "$package/System.map"
} >"$package/BUILD-INFO.txt"

export PACKAGE="$package"
export OUTPUT="$output"
export BUILD_LABEL='r31 source-built; physical early stack before final map'
export LINUX_BASE=0xa4000000
export EXTRA_CFLAGS='-DCORRECT_CACHE_HANDOFF=1 -DSKIP_EL_DIAGNOSTIC=1'
export CMDLINE_EXTRA='maxcpus=1'

exec "$project/scripts/build-linux-6.12-direct-recovery-r17-proven-v56-wrapper.sh"
