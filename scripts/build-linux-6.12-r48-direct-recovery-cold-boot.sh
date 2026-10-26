#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"

export PACKAGE=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r48-post-map-mem-checkpoint
export OUTPUT=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-direct-recovery-r48-cold-boot
export BUILD_LABEL='r48 cold-boot (no kexec): checkpoint after map_mem() in paging_init(), same Image as the r48 kexec test'
export LINUX_BASE=0xa4000000
export EXTRA_CFLAGS='-DCORRECT_CACHE_HANDOFF=1 -DSKIP_EL_DIAGNOSTIC=1'
export CMDLINE_EXTRA='maxcpus=1 earlycon keep_bootcon ignore_loglevel loglevel=8'

exec "$project/scripts/build-linux-6.12-direct-recovery-r17-proven-v56-wrapper.sh"
