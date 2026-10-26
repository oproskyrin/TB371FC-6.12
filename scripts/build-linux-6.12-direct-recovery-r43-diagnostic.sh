#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
kernel_package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-clean-tgran-bypass-r33
payload_package='/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-arch612-diag39+-safe-diag39-r2'
v56=/mnt/d/TB371FC-builds/arch-development-loader-v56-5-r2-community-simplefb-qca6390-kde-kexec-cpu-hotplug-safe/tb371fc-arch-development-loader-v56-5-r2-community-simplefb-qca6390-kde-kexec-cpu-hotplug-safe-recovery.img
output=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-direct-recovery-r43-diagnostic

native_dtb="$payload_package/dtb/qcom/sm8250-lenovo-tb371fc-archsafe-microsd.dtb"
base_ramdisk="$payload_package/initramfs-6.12-arch-development.cpio.gz"
for input in "$kernel_package/Image" "$native_dtb" "$base_ramdisk" "$v56"; do test -s "$input"; done
test ! -e "$output" || { echo "Refusing to overwrite $output" >&2; exit 1; }

stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT
mkdir -p "$stage/v56-unpacked" "$stage/initramfs"

cd "$stage/initramfs"
gzip -dc "$base_ramdisk" | cpio -idm --quiet || true
install -m0755 "$project/initramfs/init-direct-diagnostic-r43" init
install -m0755 "$project/initramfs/tb371fc-early-diag-r43" bin/tb371fc-early-diag-r43
printf '%s\n' 'TB371FC-R43-DIAGNOSTICS' >etc/tb371fc-r43-diagnostics
find . -print0 | sort -z | cpio --null -o --format=newc --owner=0:0 2>/dev/null | gzip -9n >"$stage/initramfs-r43.cpio.gz"
gzip -t "$stage/initramfs-r43.cpio.gz"

python3 /root/mkbootimg/unpack_bootimg.py --boot_img "$v56" --out "$stage/v56-unpacked" >/dev/null
python3 "$project/scripts/extract-concatenated-dtb.py" "$stage/v56-unpacked/dtb" "$stage/input-entries" >/dev/null
original="$stage/input-entries/entry-00.dtb"
patched="$stage/native-tb371fc-with-abl-ids.dtb"
bundle="$stage/v56-container-native-board-dtb.img"
cp "$native_dtb" "$patched"
for property in qcom,msm-id qcom,board-id qcom,pmic-id; do
	if values=$(fdtget -t x "$original" / "$property" 2>/dev/null); then
		# shellcheck disable=SC2086
		fdtput -t x "$patched" / "$property" $values
	fi
done
python3 "$project/scripts/replace-concatenated-dtb-entry.py" "$stage/v56-unpacked/dtb" 0 "$patched" "$bundle"
python3 "$project/scripts/extract-concatenated-dtb.py" "$bundle" "$stage/output-entries" >/dev/null
cmp "$patched" "$stage/output-entries/entry-00.dtb"
for index in 01 02 03; do cmp "$stage/input-entries/entry-$index.dtb" "$stage/output-entries/entry-$index.dtb"; done

export PACKAGE="$kernel_package"
export OUTPUT="$output"
export BUILD_LABEL='r43 V56.5 wrapper, native Linux 6.12 board DTB, persistent early diagnostics'
export LINUX_BASE=0xa4000000
export EXTRA_CFLAGS='-DCORRECT_CACHE_HANDOFF=1 -DSKIP_EL_DIAGNOSTIC=1'
export CMDLINE_EXTRA='maxcpus=1 earlycon keep_bootcon ignore_loglevel loglevel=8 initcall_debug log_buf_len=16M printk.time=1 panic=30'
export RAMDISK_OVERRIDE="$stage/initramfs-r43.cpio.gz"
export DTB_OVERRIDE="$bundle"

"$project/scripts/build-linux-6.12-direct-recovery-r17-proven-v56-wrapper.sh"

mkdir -p "$output/verification-initramfs"
cd "$output/verification-initramfs"
gzip -dc "$output/unpacked/ramdisk" | cpio -idm --quiet || true
grep -q TB371FC-R43-DIAGNOSTICS etc/tb371fc-r43-diagnostics
test -x bin/tb371fc-early-diag-r43
grep -q 'userspace reached' init
sha256sum "$output/recovery.img" "$output/unpacked/kernel" "$output/unpacked/dtb" "$output/unpacked/ramdisk" >"$output/SHA256SUMS-r43.txt"
echo "r43 recovery: $output/recovery.img"
cat "$output/SHA256SUMS-r43.txt"
