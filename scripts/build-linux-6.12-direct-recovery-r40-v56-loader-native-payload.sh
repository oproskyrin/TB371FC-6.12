#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
kernel_package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-clean-tgran-bypass-r33
payload_package='/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-arch612-diag39+-safe-diag39-r2'
output=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-direct-recovery-r40-v56-loader-native-payload

test -s "$kernel_package/Image"
test -s "$payload_package/initramfs-6.12-arch-development.cpio.gz"
test -s "$payload_package/dtb/qcom/sm8250-lenovo-tb371fc-archsafe-microsd.dtb"
test ! -e "$output" || { echo "Refusing to overwrite $output" >&2; exit 1; }

export PACKAGE="$kernel_package"
export OUTPUT="$output"
export BUILD_LABEL='r40 V56.5 ABL loader with native Linux 6.12 DTB and initramfs'
export LINUX_BASE=0xa4000000
export EXTRA_CFLAGS='-DCORRECT_CACHE_HANDOFF=1 -DSKIP_EL_DIAGNOSTIC=1'
export CMDLINE_EXTRA='maxcpus=1 earlycon keep_bootcon ignore_loglevel loglevel=8'
export RAMDISK_OVERRIDE="$payload_package/initramfs-6.12-arch-development.cpio.gz"
export DTB_OVERRIDE="$payload_package/dtb/qcom/sm8250-lenovo-tb371fc-archsafe-microsd.dtb"

exec "$project/scripts/build-linux-6.12-direct-recovery-r17-proven-v56-wrapper.sh"
