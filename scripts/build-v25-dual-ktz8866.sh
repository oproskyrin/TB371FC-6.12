#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
base_tree=/root/tb371fc-lenovo-4.19-v18-trace-src
source_tree=/root/tb371fc-lenovo-4.19-v25-dual-ktz8866-src
old_out=/root/tb371fc-lenovo-4.19-v24-pps-trace-out
out_dir=/root/tb371fc-lenovo-4.19-v25-dual-ktz8866-out
base_commit=9d8abebf4ac4d45cf4cc11b5b6bc5e4483d10fd1

if [[ ! -e $source_tree/.git ]]; then
	git -C "$base_tree" worktree add --detach "$source_tree" "$base_commit"
fi

cd "$source_tree"
for patch_number in 0001 0002 0007 0008 0003 0010 0011; do
	kernel_patch=$(find "$project_dir/vendor-kernel/patches" -maxdepth 1 \
		-name "${patch_number}-*.patch" -print -quit)
	[[ -n $kernel_patch ]] || { echo "Missing patch $patch_number" >&2; exit 1; }
	case $patch_number in
	0001) grep -q 'CONFIG_CNSS2_DIAGNOSTIC_NO_SSR' drivers/net/wireless/cnss2/main.c && continue ;;
	0002) grep -q 'CONFIG_CNSS2_DIAGNOSTIC_SINGLE_QMI_CLIENT' drivers/net/wireless/cnss2/main.c && continue ;;
	0007) grep -q 'TB371FC panel flags' techpack/display/msm/dsi/dsi_panel.c && continue ;;
	0008) grep -q 'if (_sde_encoder_is_dsc_enabled(drm_enc) && sde_enc->cur_master) {' techpack/display/msm/sde/sde_encoder.c && continue ;;
	0003) ! grep -q 'Skipping dsi_bridge_pre_enable' techpack/display/msm/dsi/dsi_drm.c && continue ;;
	0010) grep -q 'TB371FC PPS payload' techpack/display/msm/dsi/dsi_panel.c && continue ;;
	0011) test -f drivers/video/backlight/tb371fc_ktz8866.c && continue ;;
	esac
	if git apply --recount --check "$kernel_patch" 2>/dev/null; then
		git apply --recount "$kernel_patch"
	else
		echo "Patch $patch_number is neither applicable nor marked as applied" >&2
		exit 1
	fi
done

git diff --check
mkdir -p "$out_dir"
install -m 0644 "$old_out/.config" "$out_dir/.config"
scripts/config --file "$out_dir/.config" --enable BACKLIGHT_TB371FC_KTZ8866

export PATH=/root/snapdragon-clang-10.0.7/bin:/root/gcc-64/bin:$PATH
common_make=(
	-C "$source_tree" O="$out_dir" ARCH=arm64 CC=clang
	CLANG_TRIPLE=aarch64-linux-gnu- CROSS_COMPILE=aarch64-linux-android-
)
make "${common_make[@]}" olddefconfig
make -j"$(nproc)" "${common_make[@]}" Image

image="$out_dir/arch/arm64/boot/Image"
[[ -s $image ]]
grep -q '^CONFIG_BACKLIGHT_TB371FC_KTZ8866=y$' "$out_dir/.config"
sha256sum "$image"
grep -q 'tb371fc_ktz8866_set_brightness' "$out_dir/System.map"
