#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Build the V56.3 bridge kernel. V56.2 remains the immutable rollback image.
set -euo pipefail

PROJECT=${PROJECT:-$(cd "$(dirname "$0")/.." && pwd)}
export PROJECT
export BUILD_VERSION=56.3
export BUILD_SLUG=56-3
export ENABLE_FHANDLE=1
export ENABLE_KEXEC=1
export BASE_OUTPUT=/root/tb371fc-desktop-v56-2-kde-wlan-fhandle-out
export SOURCE=/root/tb371fc-desktop-v56-3-kexec-src
export OUTPUT=/root/tb371fc-desktop-v56-3-kexec-out
export RELEASE=/root/tb371fc-desktop-v56-3-kexec-release
export BUILD_LOG=/root/tb371fc-v56-3-kexec-build.log

exec bash "$PROJECT/scripts/build-v56-1-community-kernel.sh"
