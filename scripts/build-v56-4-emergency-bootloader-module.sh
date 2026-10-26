#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

PROJECT=${PROJECT:-<repo>}
export PROJECT BUILD_VERSION=56.4 BUILD_SLUG=56-4
export SOURCE=/root/tb371fc-desktop-v56-4-kexec-drm-shutdown-src
export OUTPUT=/root/tb371fc-desktop-v56-4-kexec-drm-shutdown-out
export RELEASE=/root/tb371fc-desktop-v56-4-kexec-drm-shutdown-release
export MODULE_DIR=/root/tb371fc-v56-4-emergency-bootloader-module

exec bash "$PROJECT/scripts/build-v56-3-emergency-bootloader-module.sh"
