#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
set -eu

payload_dir=/usr/local/share/tb371fc-kexec-6.12-safe-r2
image=$payload_dir/Image-6.12.30-tb371fc-safe
dtb=$payload_dir/sm8250-lenovo-tb371fc-archsafe-microsd.dtb
initramfs=$payload_dir/initramfs-6.12-arch-development.cpio.gz
state=$payload_dir/state

kexec=/bin/kexec
[ -x "$kexec" ] || kexec=/run/tb371fc-rescue/kexec
[ -x "$kexec" ] || {
	echo 'kexec binary is unavailable' >&2
	exit 1
}

verify() {
	file=$1
	expected=$2
	[ -s "$file" ] || {
		echo "missing payload: $file" >&2
		exit 1
	}
	actual=$(sha256sum "$file" | awk '{print $1}')
	[ "$actual" = "$expected" ] || {
		echo "SHA-256 mismatch: $file" >&2
		echo "expected $expected" >&2
		echo "actual   $actual" >&2
		exit 1
	}
}

[ "$(uname -r)" = '4.19.157-perf-v56.3+' ] || {
	echo "refusing 6.12 handoff from unexpected kernel: $(uname -r)" >&2
	exit 1
}
[ "$(cat /sys/class/block/mmcblk0p1/dev 2>/dev/null || true)" = '179:1' ] || {
	echo 'microSD partition mmcblk0p1 is not available' >&2
	exit 1
}
[ -f /etc/tb371fc-development-image ] || {
	echo 'Arch development root marker is missing' >&2
	exit 1
}

verify "$image" cdbe369d7eaf92275e50f7c744383de004dd2a1881003f83fca7e36f9c82d2c7
verify "$dtb" caa9598e88b9b4a39d39916651d306824e2f44d8325822e510bcb6d0cede357c
verify "$initramfs" b7be327c96b0be729d57de861a7502cb906279fdcee45da5a8601c3691c41f05

cmdline='console=tty0 fbcon=font:TER16x32 ignore_loglevel log_buf_len=4M rdinit=/init root=/dev/ram0 rw fw_devlink=permissive clk_ignore_unused pd_ignore_unused regulator_ignore_unused panic=-1 swiotlb=2048'

rm -f "$state"
"$kexec" -u 2>/dev/null || true
"$kexec" -c -l "$image" --dtb="$dtb" --initrd="$initramfs" \
	--append="$cmdline"
printf '%s\n' 'loaded-linux-6.12.30-safe-r2-from-v56.3' >"$state"
sync
echo 'Linux 6.12 safe r2 verified and loaded in RAM; it has NOT been executed.'
