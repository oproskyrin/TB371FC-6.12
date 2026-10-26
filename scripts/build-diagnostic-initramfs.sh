#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
set -euo pipefail

usage() {
	cat <<'EOF'
Usage: build-diagnostic-initramfs.sh BUSYBOX ROOTFS FIRMWARE_DIR [OUTPUT]

BUSYBOX must be a statically linked AArch64 binary. ROOTFS must contain the
installed modules for the kernel being tested. FIRMWARE_DIR is produced by
package-stock-firmware.sh and must include ath11k board-2.bin.
EOF
}

if (( $# < 3 || $# > 4 )); then
	usage >&2
	exit 2
fi

busybox=$(realpath "$1")
rootfs=$(realpath "$2")
firmware=$(realpath "$3")
output=${4:-artifacts/tb371fc-diagnostic-initramfs.cpio.gz}
repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
init_file="$repo_dir/initramfs/init"
usb_console_file="$repo_dir/initramfs/setup-usb-console"
input_monitor_source="$repo_dir/diagnostics/input-monitor.c"

if ! file "$busybox" | grep -q 'ARM aarch64'; then
	echo "BUSYBOX is not an AArch64 executable: $busybox" >&2
	exit 1
fi
if readelf -l "$busybox" | grep -q 'Requesting program interpreter'; then
	echo "BUSYBOX must be statically linked" >&2
	exit 1
fi

if [[ -n ${KERNEL_RELEASE:-} ]]; then
	release=$KERNEL_RELEASE
	if [[ ! -d "$rootfs/usr/lib/modules/$release" ]]; then
		echo "KERNEL_RELEASE does not exist in the rootfs: $release" >&2
		exit 1
	fi
else
	mapfile -t releases < <(find "$rootfs/usr/lib/modules" -mindepth 1 -maxdepth 1 -type d -printf '%f\n')
	if (( ${#releases[@]} != 1 )); then
		echo "Multiple module releases found; set KERNEL_RELEASE explicitly" >&2
		printf '  %s\n' "${releases[@]}" >&2
		exit 1
	fi
	release=${releases[0]}
fi

output=$(realpath -m "$output")
output_parent=$(dirname "$output")
mkdir -p "$output_parent"
[[ ! -e $output ]] || {
	echo "Refusing to overwrite existing initramfs: $output" >&2
	exit 1
}

stage=$(mktemp -d)
output_tmp=$(mktemp "$output_parent/.tb371fc-initramfs.XXXXXX")
cleanup() {
	rm -rf -- "$stage"
	rm -f -- "$output_tmp"
}
trap cleanup EXIT

mkdir -p "$stage"/{bin,sbin,etc,proc,sys,dev,run,tmp,usr/lib/modules,usr/lib/firmware}
ln -s usr/lib "$stage/lib"
install -m0755 "$busybox" "$stage/bin/busybox"
install -m0755 "$init_file" "$stage/init"
install -m0755 "$usb_console_file" "$stage/bin/setup-usb-console"
aarch64-linux-gnu-gcc -static -Os -s -Wall -Wextra \
	-o "$stage/bin/input-monitor" "$input_monitor_source"
if ! file "$stage/bin/input-monitor" | grep -q 'ARM aarch64.*statically linked'; then
	echo "input-monitor is not a static AArch64 executable" >&2
	exit 1
fi
for applet in sh mount mkdir hostname dmesg cat tr ls find grep basename uname \
	setsid cttyhack poweroff modprobe getty ln ip ifconfig udhcpc lsusb lspci \
	lsmod modinfo ping telnetd reboot sleep; do
	ln -s busybox "$stage/bin/$applet"
done

# Copy each module requested for early diagnostics and its dependency closure.
modules=${MODULES:-"pwrseq-qcom-wcn ath11k_pci msm qcom-spmi-adc-tm5 nt36523_ts libcomposite usb_f_acm r8152 ax88179_178a cdc_ether"}
for module in $modules; do
	while read -r action module_path; do
		[[ $action == insmod ]] || continue
		relative=${module_path#"$rootfs"/}
		install -Dm0644 "$module_path" "$stage/$relative"
	done < <(modprobe --dirname "$rootfs" --set-version "$release" --show-depends "$module")
done

cp -a "$firmware"/. "$stage/usr/lib/firmware/"
for metadata in modules.order modules.builtin modules.builtin.modinfo; do
	if [[ -f "$rootfs/usr/lib/modules/$release/$metadata" ]]; then
		install -m0644 "$rootfs/usr/lib/modules/$release/$metadata" \
			"$stage/usr/lib/modules/$release/$metadata"
	fi
done
depmod -b "$stage" "$release"
mknod -m 600 "$stage/dev/console" c 5 1
mknod -m 666 "$stage/dev/null" c 1 3

(
	cd "$stage"
	find . -print0 | sort -z | cpio --null -o --format=newc --owner=0:0 2>/dev/null | gzip -9n >"$output_tmp"
)
mv -T "$output_tmp" "$output"
echo "Diagnostic initramfs: $output"
du -h "$output"
