#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
set -eu

payload_dir=/usr/local/share/tb371fc-kexec-6.12-desktop-gpu-r4
image=$payload_dir/Image-6.12.30-tb371fc-desktop
dtb=$payload_dir/sm8250-lenovo-tb371fc-archsafe-microsd.dtb
initramfs=$payload_dir/initramfs-6.12-arch-development.cpio.gz
state=$payload_dir/state
kexec=/bin/kexec
[ -x "$kexec" ] || kexec=/run/tb371fc-rescue/kexec
[ -x "$kexec" ] || { echo 'kexec binary is unavailable' >&2; exit 1; }

verify() {
	file=$1
	expected=$2
	[ -s "$file" ] || { echo "missing payload: $file" >&2; exit 1; }
	actual=$(sha256sum "$file" | awk '{print $1}')
	[ "$actual" = "$expected" ] || { echo "SHA-256 mismatch: $file" >&2; exit 1; }
}

case "$(uname -r)" in
	4.19.157-perf-v56.3+|4.19.157-perf-v56.5+) ;;
	*) echo "refusing 6.12 handoff from unexpected kernel: $(uname -r)" >&2; exit 1 ;;
esac
[ "$(cat /sys/class/block/mmcblk0p1/dev 2>/dev/null || true)" = '179:1' ] || {
	echo 'microSD partition mmcblk0p1 is unavailable' >&2
	exit 1
}
[ -f /etc/tb371fc-development-image ] || {
	echo 'Arch development root marker is missing' >&2
	exit 1
}

verify "$image" f7f2cd22a36ccf6fedb28a7289c1371436ffbf33aa9c9f94244916f9b61f4159
verify "$dtb" caa9598e88b9b4a39d39916651d306824e2f44d8325822e510bcb6d0cede357c
verify "$initramfs" 1a7c4fedad2bda5fb17e2e59fdc371713d944258f0cacf18f882a7a7d85320df

cmdline='console=tty0 fbcon=font:TER16x32 loglevel=8 ignore_loglevel log_buf_len=8M rdinit=/init root=/dev/ram0 rw fw_devlink=permissive clk_ignore_unused pd_ignore_unused regulator_ignore_unused drm.debug=0x1ff panic=-1 swiotlb=2048'
rm -f "$state"
"$kexec" -u 2>/dev/null || true
"$kexec" -c -l "$image" --dtb="$dtb" --initrd="$initramfs" --append="$cmdline"
printf '%s\n' 'loaded-linux-6.12.30-desktop-gpu-r4-not-executed' >"$state"
sync
echo 'Linux 6.12 desktop GPU r4 is verified and loaded in RAM; it has NOT been executed.'
