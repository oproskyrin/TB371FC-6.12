#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export KERNEL_DIR="${KERNEL_DIR:-$HOME/tb371fc-linux-7.1.7-full-panel-verify}"
export OUT_DIR="${OUT_DIR:-$HOME/tb371fc-linux-7.1.7-display-test-out}"
export BUILD_TARGETS="Image qcom/sm8250-lenovo-tb371fc-display-test.dtb"
export JOBS="${JOBS:-$(nproc)}"

exec "$PROJECT_DIR/scripts/build-kernel.sh"
