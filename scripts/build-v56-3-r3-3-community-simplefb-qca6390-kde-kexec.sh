#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# V56.3-r3.3: reject obsolete persistent service overrides before KDE starts.
set -euo pipefail

PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
export BUILD_VERSION=56.3
export BUILD_SLUG=56-3-r3-3
export BUILD_RELEASE=/root/tb371fc-desktop-v56-3-r3-release
export INCLUDE_KEXEC=1
export OUTPUT_ROOT="$PROJECT/artifacts/arch-development-loader-v56-3-r3-3-community-simplefb-qca6390-kde-kexec-safe"
export OUTPUT_RAMDISK=$OUTPUT_ROOT/tb371fc-v56-3-r3-3-simplefb-qca6390-kde-kexec-safe.cpio.gz
export OUTPUT_IMAGE=$OUTPUT_ROOT/tb371fc-arch-development-loader-v56-3-r3-3-community-simplefb-qca6390-kde-kexec-safe-recovery.img

exec bash "$PROJECT/scripts/build-v56-1-community-simplefb-qca6390-kde.sh"
