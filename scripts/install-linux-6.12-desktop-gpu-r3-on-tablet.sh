#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
set -eu

stage=/tmp/tb371fc-linux-6.12-desktop-gpu-r3
share=/usr/local/share/tb371fc-kexec-6.12-desktop-gpu-r3
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
verify "$stage/initramfs.cpio.gz" 3d3db310cb8518ed78fd60585183d97cb338d29dff075e37d162437e9f3e582d
verify "$stage/modules.tar.gz" 32650c9f6e6d265198a8e88dc9f9c388703d31946887e5fb935532e5cddbbb8a
verify "$stage/firmware.tar.gz" dcf788f673541e24d7f0c2b101706c985157367cddd6bb3443954ebca843d88c
verify "$stage/watchdog-v56.3.ko" bd56263c0f395a367fa82c15644c8228831b580a78b4dd2c3308c04046dcb815
verify "$stage/watchdog-v56.5.ko" 00d587499331fd05eb15bea0799cbd288bab25f168492dfcd43a0b809e557bd7

mkdir -p "$share" "$lib" "$sbin"
install -m0644 "$stage/Image" "$share/Image-6.12.30-tb371fc-desktop"
install -m0644 "$stage/board.dtb" "$share/sm8250-lenovo-tb371fc-archsafe-microsd.dtb"
install -m0644 "$stage/initramfs.cpio.gz" "$share/initramfs-6.12-arch-development.cpio.gz"
install -m0644 "$stage/watchdog-v56.3.ko" "$lib/kexec-failsafe-bootloader-watchdog-v56.3-r3.3.ko"
install -m0644 "$stage/watchdog-v56.5.ko" "$lib/kexec-failsafe-bootloader-watchdog-v56.5.ko"
install -m0755 "$stage/load.sh" "$sbin/tb371fc-load-linux-6.12-desktop-gpu-r3"
install -m0755 "$stage/execute.sh" "$sbin/tb371fc-execute-linux-6.12-desktop-gpu-r3"
install -m0755 "$stage/capture-gpu.sh" "$sbin/tb371fc-capture-linux-6.12-gpu"
tar -xzf "$stage/modules.tar.gz" -C /
tar -xzf "$stage/firmware.tar.gz" -C /
depmod 6.12.30-tb371fc-arch612-desktop+
sync

verify "$share/Image-6.12.30-tb371fc-desktop" f7f2cd22a36ccf6fedb28a7289c1371436ffbf33aa9c9f94244916f9b61f4159
echo 'TB371FC_LINUX_6_12_DESKTOP_GPU_R3_STAGED_NOT_EXECUTED'
