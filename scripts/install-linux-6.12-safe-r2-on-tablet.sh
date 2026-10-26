#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
set -eu

stage=/tmp/tb371fc-linux-6.12-safe-r2
share=/usr/local/share/tb371fc-kexec-6.12-safe-r2
lib=/usr/local/lib/tb371fc
sbin=/usr/local/sbin

verify() {
	file=$1
	expected=$2
	actual=$(sha256sum "$file" | awk '{print $1}')
	[ "$actual" = "$expected" ] || {
		echo "SHA-256 mismatch: $file" >&2
		exit 1
	}
}

[ "$(uname -r)" = '4.19.157-perf-v56.3+' ] || {
	echo "unexpected installer kernel: $(uname -r)" >&2
	exit 1
}
verify "$stage/Image" cdbe369d7eaf92275e50f7c744383de004dd2a1881003f83fca7e36f9c82d2c7
verify "$stage/sm8250-lenovo-tb371fc-archsafe-microsd.dtb" caa9598e88b9b4a39d39916651d306824e2f44d8325822e510bcb6d0cede357c
verify "$stage/initramfs-6.12-arch-development.cpio.gz" b7be327c96b0be729d57de861a7502cb906279fdcee45da5a8601c3691c41f05
verify "$stage/modules.tar.gz" 88b37f58e081dc38025482d99bf551361b0a4fb78285de0cfba2f3ca2583de7a
verify "$stage/kexec-failsafe-bootloader-watchdog-v56.3-r3.3.ko" bd56263c0f395a367fa82c15644c8228831b580a78b4dd2c3308c04046dcb815

mkdir -p "$share" "$lib" "$sbin"
install -m0644 "$stage/Image" "$share/Image-6.12.30-tb371fc-safe"
install -m0644 "$stage/sm8250-lenovo-tb371fc-archsafe-microsd.dtb" "$share/"
install -m0644 "$stage/initramfs-6.12-arch-development.cpio.gz" "$share/"
install -m0644 "$stage/kexec-failsafe-bootloader-watchdog-v56.3-r3.3.ko" "$lib/"
install -m0755 "$stage/load-linux-6.12-safe-r2.sh" "$sbin/tb371fc-load-linux-6.12-safe-r2"
install -m0755 "$stage/execute-linux-6.12-safe-r2-failsafe.sh" "$sbin/tb371fc-execute-linux-6.12-safe-r2"
tar -xzf "$stage/modules.tar.gz" -C /
depmod 6.12.30-tb371fc-arch612-safe+
sync

verify "$share/Image-6.12.30-tb371fc-safe" cdbe369d7eaf92275e50f7c744383de004dd2a1881003f83fca7e36f9c82d2c7
echo 'TB371FC_LINUX_6_12_SAFE_R2_STAGED_NOT_EXECUTED'
