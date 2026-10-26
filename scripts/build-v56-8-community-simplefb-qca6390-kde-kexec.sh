#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Package V56.8 without modifying the V56.7 or V56.5 rollback images.
set -euo pipefail

PROJECT=<repo>
export BUILD_VERSION=56.8
export BUILD_SLUG=56-8
export BUILD_RELEASE=/root/tb371fc-desktop-v56-8-native-clock-release
export INCLUDE_KEXEC=1
export OUTPUT_ROOT=/mnt/d/TB371FC-builds/arch-development-loader-v56-8-r1-community-simplefb-qca6390-kde-kexec-native-clock
export OUTPUT_RAMDISK=$OUTPUT_ROOT/tb371fc-v56-8-r1-simplefb-qca6390-kde-kexec-native-clock.cpio.gz
export OUTPUT_IMAGE=$OUTPUT_ROOT/tb371fc-arch-development-loader-v56-8-r1-community-simplefb-qca6390-kde-kexec-native-clock-recovery.img

exec bash "$PROJECT/scripts/build-v56-1-community-simplefb-qca6390-kde.sh"
