#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

PROJECT=${PROJECT:-<repo>}
export PROJECT
export BUILD_VERSION=56.2
export BUILD_SLUG=56-2
export ENABLE_FHANDLE=1
export BASE_OUTPUT=/root/tb371fc-desktop-v56-1-kde-wlan-safe-out
export SOURCE=/root/tb371fc-desktop-v56-2-kde-wlan-fhandle-src
export OUTPUT=/root/tb371fc-desktop-v56-2-kde-wlan-fhandle-out
export RELEASE=/root/tb371fc-desktop-v56-2-kde-wlan-fhandle-release
export BUILD_LOG=/root/tb371fc-v56-2-kernel-build.log

exec bash "$PROJECT/scripts/build-v56-1-community-kernel.sh"
