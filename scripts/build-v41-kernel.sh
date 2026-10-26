#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
base_tree=/root/tb371fc-lenovo-4.19-v18-trace-src
v40_tree=/root/tb371fc-lenovo-4.19-v40-frame-boundary-src
source_tree=/root/tb371fc-lenovo-4.19-v41-splash-state-src
old_out=/root/tb371fc-lenovo-4.19-v40-frame-boundary-out
out_dir=/root/tb371fc-lenovo-4.19-v41-splash-state-out
base_commit=9d8abebf4ac4d45cf4cc11b5b6bc5e4483d10fd1

if [[ ! -e $source_tree/.git ]]; then
	git -C "$base_tree" worktree add --detach "$source_tree" "$base_commit"
	git -C "$v40_tree" diff --binary | git -C "$source_tree" apply --recount
fi

cd "$source_tree"
if ! grep -q 'TB371FC importing continuous-splash video state' \
		techpack/display/msm/dsi/dsi_ctrl.c; then
	patch -p1 --dry-run --batch \
		<"$project_dir/vendor-kernel/patches/0017-tb371fc-import-splash-video-state.patch"
	patch -p1 --batch \
		<"$project_dir/vendor-kernel/patches/0017-tb371fc-import-splash-video-state.patch"
fi

git diff --check
mkdir -p "$out_dir"
install -m 0644 "$old_out/.config" "$out_dir/.config"

export PATH=/root/snapdragon-clang-10.0.7/bin:/root/gcc-64/bin:$PATH
common_make=(
	-C "$source_tree" O="$out_dir" ARCH=arm64 CC=clang
	CLANG_TRIPLE=aarch64-linux-gnu- CROSS_COMPILE=aarch64-linux-android-
)
make "${common_make[@]}" olddefconfig
make -j"$(nproc)" "${common_make[@]}" Image

image="$out_dir/arch/arm64/boot/Image"
[[ -s $image ]]
grep -q 'TB371FC importing continuous-splash video state' "$image"
grep -q 'TB371FC quiescing inherited video before splash PPS' "$image"
sha256sum "$image"
