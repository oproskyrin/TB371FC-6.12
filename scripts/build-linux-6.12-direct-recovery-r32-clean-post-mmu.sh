#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
kernel_dir=/root/tb371fc/linux-6.12-donor
out_dir=/root/tb371fc/build-6.12-mmu-diag
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-clean-post-mmu-r32
output=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-direct-recovery-r32-clean-post-mmu
stack_patch="$project/mainline-port/patches/0025-arm64-tb371fc-use-physical-early-stack-before-final-map.patch"

test -d "$kernel_dir/.git"
test -f "$out_dir/.config"
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }
test ! -e "$output" || { echo "Refusing to overwrite $output" >&2; exit 1; }

# The r31 physical-stack hypothesis was based on a marker that itself could
# generate an asynchronous external abort. Restore the upstream 6.12 flow.
if git -C "$kernel_dir" apply --reverse --check "$stack_patch" 2>/dev/null; then
	git -C "$kernel_dir" apply --reverse "$stack_patch"
fi

# Every TB371FC framebuffer marker uses a physical address. Once SCTLR.M is
# set those writes are not safe until Linux has explicitly mapped the panel.
# Compile the entire diagnostic facility out for the real boot attempt.
"$kernel_dir/scripts/config" --file "$out_dir/.config" --disable TB371FC_EARLY_FB_MARKER
make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 olddefconfig
grep -qx '# CONFIG_TB371FC_EARLY_FB_MARKER is not set' "$out_dir/.config"

make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 -j"$(nproc)" Image

mkdir -p "$package"
install -m0644 "$out_dir/arch/arm64/boot/Image" "$package/Image"
install -m0644 "$out_dir/.config" "$package/config"
install -m0644 "$out_dir/System.map" "$package/System.map"
{
	echo 'TB371FC Linux 6.12 r32 clean post-MMU boot'
	echo 'All physical framebuffer diagnostics compiled out'
	echo 'Upstream early_init_stack flow restored'
	sha256sum "$package/Image" "$package/config" "$package/System.map"
} >"$package/BUILD-INFO.txt"

export PACKAGE="$package"
export OUTPUT="$output"
export BUILD_LABEL='r32 source-built; clean post-MMU boot without physical FB writes'
export LINUX_BASE=0xa4000000
export EXTRA_CFLAGS='-DCORRECT_CACHE_HANDOFF=1 -DSKIP_EL_DIAGNOSTIC=1'
export CMDLINE_EXTRA='maxcpus=1 earlycon keep_bootcon ignore_loglevel loglevel=8'

exec "$project/scripts/build-linux-6.12-direct-recovery-r17-proven-v56-wrapper.sh"
