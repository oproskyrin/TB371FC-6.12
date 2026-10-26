#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Package V56.4 with the complete kexec handoff toolset.
set -euo pipefail

PROJECT=<repo>
export BUILD_VERSION=56.4
export BUILD_SLUG=56-4
export BUILD_RELEASE=/root/tb371fc-desktop-v56-4-kexec-drm-shutdown-release
export INCLUDE_KEXEC=1
export OUTPUT_ROOT=/mnt/d/TB371FC-builds/arch-development-loader-v56-4-r2-community-simplefb-qca6390-kde-kexec-drm-shutdown-safe
export OUTPUT_RAMDISK=$OUTPUT_ROOT/tb371fc-v56-4-r2-simplefb-qca6390-kde-kexec-drm-shutdown-safe.cpio.gz
export OUTPUT_IMAGE=$OUTPUT_ROOT/tb371fc-arch-development-loader-v56-4-r2-community-simplefb-qca6390-kde-kexec-drm-shutdown-safe-recovery.img

exec bash "$PROJECT/scripts/build-v56-1-community-simplefb-qca6390-kde.sh"
