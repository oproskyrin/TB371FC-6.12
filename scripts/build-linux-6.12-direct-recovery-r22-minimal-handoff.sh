#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
export OUTPUT=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-direct-recovery-r22-minimal-handoff
export BUILD_LABEL='r22 r20 MMU fix; minimal direct branch after copy'
export EXTRA_CFLAGS='-DSKIP_CACHE_MAINTENANCE=1 -DSKIP_HANDOFF_BARRIERS=1 -DDIRECT_BRANCH_AFTER_BLUE=1'
exec "$project/scripts/build-linux-6.12-direct-recovery-r20-skip-false-granule-reject.sh"
