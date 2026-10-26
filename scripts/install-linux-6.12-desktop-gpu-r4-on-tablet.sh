#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
set -eu

stage=/tmp/tb371fc-linux-6.12-desktop-gpu-r4
share=/usr/local/share/tb371fc-kexec-6.12-desktop-gpu-r4
lib=/usr/local/lib/tb371fc
sbin=/usr/local/sbin

verify() {
	file=$1
	expected=$2
	[ -s "$file" ] || { echo "missing staged file: $file" >&2; exit 1; }
	actual=$(sha256sum "$file" | awk '{print $1}')
	[ "$actual" = "$expected" ] || { echo "SHA-256 mismatch: $file" >&2; exit 1; }
}

case "$(uname -r)" in
	4.19.157-perf-v56.3+|4.19.157-perf-v56.5+) ;;
	*) echo "unexpected installer kernel: $(uname -r)" >&2; exit 1 ;;
esac

verify "$stage/Image" f7f2cd22a36ccf6fedb28a7289c1371436ffbf33aa9c9f94244916f9b61f4159
verify "$stage/board.dtb" caa9598e88b9b4a39d39916651d306824e2f44d8325822e510bcb6d0cede357c
verify "$stage/initramfs.cpio.gz" 1a7c4fedad2bda5fb17e2e59fdc371713d944258f0cacf18f882a7a7d85320df
verify "$stage/modules.tar.gz" c0d87d868cfd45dbd9267240f76a4fd02b82f4e4ff92a2dd41c0901007a0da00
verify "$stage/firmware.tar.gz" 47ca5262416d1a2c0cf20c89bfb3763d47b3e405f9800048056a53e63a278d6a
verify "$stage/watchdog-v56.3.ko" bd56263c0f395a367fa82c15644c8228831b580a78b4dd2c3308c04046dcb815
verify "$stage/watchdog-v56.5.ko" 00d587499331fd05eb15bea0799cbd288bab25f168492dfcd43a0b809e557bd7

mkdir -p "$share" "$lib" "$sbin"
install -m0644 "$stage/Image" "$share/Image-6.12.30-tb371fc-desktop"
install -m0644 "$stage/board.dtb" "$share/sm8250-lenovo-tb371fc-archsafe-microsd.dtb"
install -m0644 "$stage/initramfs.cpio.gz" "$share/initramfs-6.12-arch-development.cpio.gz"
install -m0644 "$stage/watchdog-v56.3.ko" "$lib/kexec-failsafe-bootloader-watchdog-v56.3-r3.3.ko"
install -m0644 "$stage/watchdog-v56.5.ko" "$lib/kexec-failsafe-bootloader-watchdog-v56.5.ko"
install -m0755 "$stage/load.sh" "$sbin/tb371fc-load-linux-6.12-desktop-gpu-r4"
install -m0755 "$stage/execute.sh" "$sbin/tb371fc-execute-linux-6.12-desktop-gpu-r4"
install -m0755 "$stage/capture-gpu.sh" "$sbin/tb371fc-capture-linux-6.12-gpu"
tar -xzf "$stage/modules.tar.gz" -C /
tar -xzf "$stage/firmware.tar.gz" -C /
depmod 6.12.30-tb371fc-arch612-desktop+
sync

verify "$share/Image-6.12.30-tb371fc-desktop" f7f2cd22a36ccf6fedb28a7289c1371436ffbf33aa9c9f94244916f9b61f4159
echo 'TB371FC_LINUX_6_12_DESKTOP_GPU_R4_STAGED_NOT_EXECUTED'
