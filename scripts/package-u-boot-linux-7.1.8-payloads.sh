#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
release_dir=${RELEASE_DIR:-/mnt/d/TB371FC-builds/linux-7.1.8-tb371fc-offline}
initramfs=${INITRAMFS:-/mnt/d/TB371FC-builds/diagnostic-7.1.8-stage0-minimal-initramfs.cpio.gz}
output_dir=${1:-/mnt/d/TB371FC-builds/u-boot-linux-7.1.8-payloads}
mkbootimg=${MKBOOTIMG:-/root/mkbootimg/mkbootimg.py}
payload_kind=${PAYLOAD_KIND:-diagnostic}
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT

case "$payload_kind" in
	diagnostic)
		filename_suffix=
		variants=(stage0 display-test)
		;;
	arch-development)
		filename_suffix=-arch-development
		variants=(arch-test)
		;;
	*) echo "Unsupported PAYLOAD_KIND: $payload_kind" >&2; exit 1 ;;
esac

[[ ! -e $output_dir ]] || { echo "Refusing to overwrite: $output_dir" >&2; exit 1; }
for input in "$release_dir/Image" "$initramfs" "$mkbootimg"; do
	[[ -s $input ]] || { echo "Missing payload input: $input" >&2; exit 1; }
done
mkdir -p "$output_dir"
gzip -n -9 -c "$release_dir/Image" >"$stage/Image.gz"
gzip -t "$stage/Image.gz"
gzip -dc "$stage/Image.gz" | cmp - "$release_dir/Image"

cmdline='console=tty0 fbcon=font:TER16x32 ignore_loglevel log_buf_len=4M rdinit=/init root=/dev/ram0 rw fw_devlink=permissive clk_ignore_unused pd_ignore_unused panic=-1 swiotlb=2048'
for variant in "${variants[@]}"; do
	case "$variant" in
	stage0) dtb_name=sm8250-lenovo-tb371fc-stage0 ;;
	display-test) dtb_name=sm8250-lenovo-tb371fc-display-test ;;
	arch-test) dtb_name=sm8250-lenovo-tb371fc-arch-test ;;
	esac
	dtb="$release_dir/dtb/qcom/$dtb_name.dtb"
	output="$output_dir/tb371fc-linux-7.1.8-$variant$filename_suffix-u-boot.img"
	[[ -s $dtb ]] || { echo "Missing DTB: $dtb" >&2; exit 1; }
	DIAGNOSTIC_CMDLINE="$cmdline" "$project_dir/scripts/build-diagnostic-boot.sh" \
		"$mkbootimg" "$stage/Image.gz" "$initramfs" "$dtb" "$output"
	done

{
	echo 'platform=Lenovo TB371FC'
	echo 'kernel_release=7.1.8-tb371fc'
	echo "payload_kind=$payload_kind"
	echo 'transport=U-Boot fastboot download; RAM boot only'
	echo 'kernel_encoding=deterministic gzip; U-Boot decompresses to 2-MiB-aligned kernel_addr_r'
	echo 'hardware_status=OFFLINE VERIFIED; NOT BOOTED'
	if [[ $payload_kind == diagnostic ]]; then
		echo 'stage0_payload=no native display; USB/console diagnostic first'
		echo 'display_payload=dual DSI 2944x1840@120; attended test only'
	else
		echo 'arch_payload=no native display; conservative 25-MHz/3.3-V microSD Arch handoff and SSH bridge'
		echo 'root_contract=microSD exFAT -> 6..64 GiB loop-ext4 development image'
		echo 'services=USB ACM/NCM rescue before switch_root; key-only OpenSSH after handoff'
	fi
	echo 'warning=Do not use fastboot flash. U-Boot has flash backend disabled.'
} >"$output_dir/README.txt"
(
	cd "$output_dir"
	find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum
) >"$output_dir/SHA256SUMS"
(cd "$output_dir" && sha256sum -c SHA256SUMS)
du -sh "$output_dir"
