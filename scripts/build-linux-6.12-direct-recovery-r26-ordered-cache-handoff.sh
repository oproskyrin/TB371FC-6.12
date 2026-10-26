#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"

export OUTPUT=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-direct-recovery-r26-ordered-cache-handoff
export BUILD_LABEL='r26 r24 MMU fix; ordered ARM64 D-cache/I-cache handoff at 0xa4000000'
export LINUX_BASE=0xa4000000
export EXTRA_CFLAGS='-DCORRECT_CACHE_HANDOFF=1 -DSKIP_EL_DIAGNOSTIC=1'

exec "$project/scripts/build-linux-6.12-direct-recovery-r24-skip-tgran-read.sh"
