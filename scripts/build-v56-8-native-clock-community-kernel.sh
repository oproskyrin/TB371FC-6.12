#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Build V56.8 as a strict regression test: keep the V56.5 display clock path.
set -euo pipefail

PROJECT=${PROJECT:-$(cd "$(dirname "$0")/.." && pwd)}
export PROJECT
export BUILD_VERSION=56.8
export BUILD_SLUG=56-8
export ENABLE_FHANDLE=1
export ENABLE_KEXEC=1
export ENABLE_KEXEC_DRM_SHUTDOWN_WORKAROUND=1
export ENABLE_KEXEC_CPU_HOTPLUG_WORKAROUND=1
export ENABLE_DSI_LOGICAL_REFRESH_CLOCK=0
export BASE_SOURCE=/root/tb371fc-desktop-v56-5-kexec-cpu-hotplug-src
export BASE_OUTPUT=/root/tb371fc-desktop-v56-5-kexec-cpu-hotplug-out
export SOURCE=/root/tb371fc-desktop-v56-8-native-clock-src
export OUTPUT=/root/tb371fc-desktop-v56-8-native-clock-out
export RELEASE=/root/tb371fc-desktop-v56-8-native-clock-release
export BUILD_LOG=/root/tb371fc-v56-8-native-clock-build.log

exec bash "$PROJECT/scripts/build-v56-1-community-kernel.sh"
