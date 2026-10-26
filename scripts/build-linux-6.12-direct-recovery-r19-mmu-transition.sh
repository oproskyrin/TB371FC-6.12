#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
export PACKAGE=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-arch612-mmu-diag+-desktop-mmu-diag-r1
export OUTPUT=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-direct-recovery-r19-mmu-transition
export BUILD_LABEL='r19 MMU-transition diagnostic via proven r18 handoff'
export EXTRA_CFLAGS='-DSKIP_CACHE_MAINTENANCE=1'
exec "$project/scripts/build-linux-6.12-direct-recovery-r17-proven-v56-wrapper.sh"
