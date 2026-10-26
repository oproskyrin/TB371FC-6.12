#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
kernel_package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-clean-tgran-bypass-r33
payload_package='/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-arch612-diag39+-safe-diag39-r2'
output=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-direct-recovery-r41-v56-dtb-native-initramfs

test -s "$kernel_package/Image"
test -s "$payload_package/initramfs-6.12-arch-development.cpio.gz"
test ! -e "$output" || { echo "Refusing to overwrite $output" >&2; exit 1; }

export PACKAGE="$kernel_package"
export OUTPUT="$output"
export BUILD_LABEL='r41 V56.5 ABL DTB bundle with native Linux 6.12 initramfs'
export LINUX_BASE=0xa4000000
export EXTRA_CFLAGS='-DCORRECT_CACHE_HANDOFF=1 -DSKIP_EL_DIAGNOSTIC=1'
export CMDLINE_EXTRA='maxcpus=1 earlycon keep_bootcon ignore_loglevel loglevel=8'
export RAMDISK_OVERRIDE="$payload_package/initramfs-6.12-arch-development.cpio.gz"

# Deliberately retain the complete V56.5 Qualcomm DTB bundle in the Android
# boot header.  Lenovo ABL rejects a raw single Linux DTB before the direct
# entry wrapper gets control.  ABL selects and patches the matching board DTB,
# including the native initramfs addresses, before entering the wrapper.
unset DTB_OVERRIDE

exec "$project/scripts/build-linux-6.12-direct-recovery-r17-proven-v56-wrapper.sh"
