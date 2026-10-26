#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_tree=/root/tb371fc-lenovo-4.19-v41-splash-state-src
out_dir=/root/tb371fc-lenovo-4.19-v41-splash-state-out

grep -q 'TB371FC scheduling splash PPS on inherited video frame' \
	"$source_tree/techpack/display/msm/dsi/dsi_display.c"
git -C "$source_tree" diff --check

export PATH=/root/snapdragon-clang-10.0.7/bin:/root/gcc-64/bin:$PATH
common_make=(
	-C "$source_tree" O="$out_dir" ARCH=arm64 CC=clang
	CLANG_TRIPLE=aarch64-linux-gnu- CROSS_COMPILE=aarch64-linux-android-
)
make -j"$(nproc)" "${common_make[@]}" Image

image="$out_dir/arch/arm64/boot/Image"
[[ -s $image ]]
grep -q 'TB371FC importing continuous-splash video state' "$image"
grep -q 'TB371FC scheduling splash PPS on inherited video frame' "$image"
sha256sum "$image"
