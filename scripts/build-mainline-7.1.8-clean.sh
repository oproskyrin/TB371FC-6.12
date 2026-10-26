#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export KERNEL_DIR=${KERNEL_DIR:-/root/tb371fc-linux-7.1.8-clean}
export OUT_DIR=${OUT_DIR:-/root/tb371fc-linux-7.1.8-clean-out}
export JOBS=${JOBS:-$(nproc)}

exec "$project_dir/scripts/build-kernel.sh"
