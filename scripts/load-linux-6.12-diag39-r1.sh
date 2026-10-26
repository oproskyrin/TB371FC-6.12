#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
set -eu

payload_dir=/usr/local/share/tb371fc-kexec-6.12-diag39-r1
image=$payload_dir/Image
dtb=$payload_dir/board.dtb
initramfs=$payload_dir/initramfs.cpio.gz
kexec=/bin/kexec
[ -x "$kexec" ] || kexec=/run/tb371fc-rescue/kexec
[ -x "$kexec" ] || { echo 'kexec binary is unavailable' >&2; exit 1; }

verify() {
	actual=$(sha256sum "$1" | awk '{print $1}')
	[ "$actual" = "$2" ] || { echo "SHA-256 mismatch: $1" >&2; exit 1; }
}

[ "$(uname -r)" = '4.19.157-perf-v56.5+' ] || {
	echo "unexpected source kernel: $(uname -r)" >&2; exit 1;
}
[ "$(cat /sys/class/block/mmcblk0p1/dev 2>/dev/null || true)" = '179:1' ] || {
	echo 'microSD is unavailable' >&2; exit 1;
}
verify "$image" b26871e12490ee0e796e9bca28bb0b577fcfaa8d9e20d8df0de062697dbfa64b
verify "$dtb" caa9598e88b9b4a39d39916651d306824e2f44d8325822e510bcb6d0cede357c
verify "$initramfs" 0bf1e372fa56a897f95eb577a8beee18729c01828dff1f291ceaa157c93d2eeb

cmdline='console=tty0 fbcon=font:TER16x32 earlycon=qcom_geni,0x988000 keep_bootcon ignore_loglevel log_buf_len=8M rdinit=/init root=/dev/ram0 rw fw_devlink=permissive clk_ignore_unused pd_ignore_unused regulator_ignore_unused panic=-1 swiotlb=2048'
"$kexec" -u 2>/dev/null || true
"$kexec" -c -l "$image" --dtb="$dtb" --initrd="$initramfs" --append="$cmdline"
sync
echo 'Linux 6.12 diag39 r1 loaded in RAM; not executed.'
