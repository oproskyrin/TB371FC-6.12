#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Install the V56.5 kexec test set alongside immutable rollback runtimes.
set -eu

stage=/tmp/tb371fc-v56-5-runtime-stage
share=/usr/local/share/tb371fc-kexec-r7-v56-5
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
verify "$stage/initramfs-7.1.8-r8-arch-development-graphics-capture.cpio.gz" \
	764bb847d9970cc77fddfd1dbe26b6151127151bb60026e6cdc6ef434fae13e4
verify "$stage/kexec-failsafe-bootloader-watchdog-v56.5.ko" \
	00d587499331fd05eb15bea0799cbd288bab25f168492dfcd43a0b809e557bd7
verify "$stage/reboot-bootloader-emergency-v56.5.ko" \
	69242fd01c95d395b4d95d8e8e059476933ae215ffe02db099b580a94b6c1b92
verify "$stage/load-mainline-kexec-r7-v56-5" \
	b796cee8668f198f052d28e645d19de5df0fefd49c768ca71619ebc2320027e7
verify "$stage/execute-mainline-kexec-r7-v56-5" \
	dfdba6c3c05d537476b3a318522c2a0af7e2878c62d9b58863842f174c2ea0e0
verify "$stage/tb371fc-execute-r7-kexec-failsafe-v56-5" \
	756c27f312d969db0eae3ef6f714835a306409dcd81616038bae0a8597e245f7
verify "$stage/tb371fc-force-bootloader-v56-5" \
	a8cd5d3031d20dceb1f46ce719ab67fa900ed95e645ad292229bc7aa0ed6b429

mkdir -p "$share" "$lib" "$sbin"
install -m0644 "$stage/Image-7.1.8-tb371fc" "$share/"
install -m0644 "$stage/sm8250-lenovo-tb371fc-arch-test.dtb" "$share/"
install -m0644 "$stage/initramfs-7.1.8-r8-arch-development-graphics-capture.cpio.gz" "$share/"
install -m0755 "$stage/load-mainline-kexec-r7-v56-5" "$share/"
install -m0755 "$stage/execute-mainline-kexec-r7-v56-5" "$share/"
install -m0644 "$stage/kexec-failsafe-bootloader-watchdog-v56.5.ko" "$lib/"
install -m0644 "$stage/reboot-bootloader-emergency-v56.5.ko" "$lib/"
install -m0755 "$stage/tb371fc-execute-r7-kexec-failsafe-v56-5" "$sbin/"
install -m0755 "$stage/tb371fc-force-bootloader-v56-5" "$sbin/"
sync

verify "$share/Image-7.1.8-tb371fc" \
	fbf98ceb6839344be9e601149473ce55178dd0330228b2c176bdba77fabbd483
verify "$lib/kexec-failsafe-bootloader-watchdog-v56.5.ko" \
	00d587499331fd05eb15bea0799cbd288bab25f168492dfcd43a0b809e557bd7
verify "$lib/reboot-bootloader-emergency-v56.5.ko" \
	69242fd01c95d395b4d95d8e8e059476933ae215ffe02db099b580a94b6c1b92

echo 'V56_5_RUNTIME_STAGE_READY'
