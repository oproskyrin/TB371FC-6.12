#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
export OUTPUT=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-direct-recovery-r18-mu-cache-handoff
export BUILD_LABEL='r18 proven V56 wrapper, Mu-style cache handoff'
export EXTRA_CFLAGS='-DSKIP_CACHE_MAINTENANCE=1'
exec bash "$project/scripts/build-linux-6.12-direct-recovery-r17-proven-v56-wrapper.sh"
