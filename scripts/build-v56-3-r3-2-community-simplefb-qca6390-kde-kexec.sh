#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# V56.3-r3.2: r3.1 usability fixes plus complete Plasma process cleanup and
# automatic llvmpipe retry after an unsuccessful KGSL Turnip/Zink boot.
set -euo pipefail

PROJECT=<repo>
export BUILD_VERSION=56.3
export BUILD_SLUG=56-3-r3-2
export BUILD_RELEASE=/root/tb371fc-desktop-v56-3-r3-release
export INCLUDE_KEXEC=1
export OUTPUT_ROOT="$PROJECT/artifacts/arch-development-loader-v56-3-r3-2-community-simplefb-qca6390-kde-kexec-safe"
export OUTPUT_RAMDISK=$OUTPUT_ROOT/tb371fc-v56-3-r3-2-simplefb-qca6390-kde-kexec-safe.cpio.gz
export OUTPUT_IMAGE=$OUTPUT_ROOT/tb371fc-arch-development-loader-v56-3-r3-2-community-simplefb-qca6390-kde-kexec-safe-recovery.img

exec bash "$PROJECT/scripts/build-v56-1-community-simplefb-qca6390-kde.sh"
