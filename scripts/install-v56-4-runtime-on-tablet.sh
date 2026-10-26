#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Install the V56.4 kexec test set alongside the immutable V56.3 rollback set.
set -eu

stage=/tmp/tb371fc-v56-4-runtime-stage
share=/usr/local/share/tb371fc-kexec-r7-v56-4
lib=/usr/local/lib/tb371fc
sbin=/usr/local/sbin

verify() {
	file=$1
	expected=$2
	actual=$(sha256sum "$file" | awk '{print $1}')
	[ "$actual" = "$expected" ] || {
		echo "SHA-256 mismatch: $file" >&2
		echo "expected $expected" >&2
		echo "actual   $actual" >&2
		exit 1
	}
}

verify "$stage/Image-7.1.8-tb371fc" \
	fbf98ceb6839344be9e601149473ce55178dd0330228b2c176bdba77fabbd483
verify "$stage/sm8250-lenovo-tb371fc-arch-test.dtb" \
	5e7785ebbb7de0f79f7ce4f625da98aa63a8a6cb77451972497adc8dee67ce03
verify "$stage/initramfs-7.1.8-r7-arch-development.cpio.gz" \
	b7be327c96b0be729d57de861a7502cb906279fdcee45da5a8601c3691c41f05
verify "$stage/kexec-failsafe-bootloader-watchdog-v56.4.ko" \
	86d58a90e10cb4f571f798008e7fa8dad8f29a0973cd94a52bcc65bfd112a8f9
verify "$stage/reboot-bootloader-emergency-v56.4.ko" \
	de5f6798e0a8b7e704793a58fcee9c17676c1d0c2c6dc3668bff738b678449ef
verify "$stage/load-mainline-kexec-r7-v56-4" \
	d64f18c090644d740c80183d5cba4883d4951816ced19e7f47a34126cb444520
verify "$stage/execute-mainline-kexec-r7-v56-4" \
	195402f7a75f93e2b8acfdcb51e0014c7d85a2cf6ca3e62ad12f6127442a6ce8
verify "$stage/tb371fc-execute-r7-kexec-failsafe-v56-4" \
	c03050614ee5404aa7c186e5951470ac3aa789b3f0d364709c5705dedd2b14b5
verify "$stage/tb371fc-force-bootloader-v56-4" \
	2f5a71fc814c9cac361623079ef750bd6c0c0daed2acf8c740fcf745296476e2

mkdir -p "$share" "$lib" "$sbin"
install -m0644 "$stage/Image-7.1.8-tb371fc" "$share/"
install -m0644 "$stage/sm8250-lenovo-tb371fc-arch-test.dtb" "$share/"
install -m0644 "$stage/initramfs-7.1.8-r7-arch-development.cpio.gz" "$share/"
install -m0755 "$stage/load-mainline-kexec-r7-v56-4" "$share/"
install -m0755 "$stage/execute-mainline-kexec-r7-v56-4" "$share/"
install -m0644 "$stage/kexec-failsafe-bootloader-watchdog-v56.4.ko" "$lib/"
install -m0644 "$stage/reboot-bootloader-emergency-v56.4.ko" "$lib/"
install -m0755 "$stage/tb371fc-execute-r7-kexec-failsafe-v56-4" "$sbin/"
install -m0755 "$stage/tb371fc-force-bootloader-v56-4" "$sbin/"
sync

verify "$share/Image-7.1.8-tb371fc" \
	fbf98ceb6839344be9e601149473ce55178dd0330228b2c176bdba77fabbd483
verify "$lib/kexec-failsafe-bootloader-watchdog-v56.4.ko" \
	86d58a90e10cb4f571f798008e7fa8dad8f29a0973cd94a52bcc65bfd112a8f9
verify "$lib/reboot-bootloader-emergency-v56.4.ko" \
	de5f6798e0a8b7e704793a58fcee9c17676c1d0c2c6dc3668bff738b678449ef

echo 'V56_4_RUNTIME_STAGE_READY'
