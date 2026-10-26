#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
export OUTPUT=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-direct-recovery-r25-fresh-exec-address
export BUILD_LABEL='r25 r24 MMU fix at fresh 0xa4000000 execution address'
export LINUX_BASE=0xa4000000
exec "$project/scripts/build-linux-6.12-direct-recovery-r24-skip-tgran-read.sh"
