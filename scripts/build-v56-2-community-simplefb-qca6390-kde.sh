#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
export BUILD_VERSION=56.2
export BUILD_SLUG=56-2
export BUILD_RELEASE=/root/tb371fc-desktop-v56-2-kde-wlan-fhandle-release
export OUTPUT_ROOT=/mnt/d/TB371FC-builds/arch-development-loader-v56-2-community-simplefb-qca6390-kde-fhandle-safe
export OUTPUT_RAMDISK=$OUTPUT_ROOT/tb371fc-v56-2-simplefb-qca6390-kde-fhandle-safe.cpio.gz
export OUTPUT_IMAGE=$OUTPUT_ROOT/tb371fc-arch-development-loader-v56-2-community-simplefb-qca6390-kde-fhandle-safe-recovery.img

exec bash "$PROJECT/scripts/build-v56-1-community-simplefb-qca6390-kde.sh"
