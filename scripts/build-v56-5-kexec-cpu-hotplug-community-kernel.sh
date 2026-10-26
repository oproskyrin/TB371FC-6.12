#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Build the V56.5 kexec launcher; V56.3 r2 remains immutable rollback.
set -euo pipefail

PROJECT=${PROJECT:-$(cd "$(dirname "$0")/.." && pwd)}
export PROJECT
export BUILD_VERSION=56.5
export BUILD_SLUG=56-5
export ENABLE_FHANDLE=1
export ENABLE_KEXEC=1
export ENABLE_KEXEC_DRM_SHUTDOWN_WORKAROUND=1
export ENABLE_KEXEC_CPU_HOTPLUG_WORKAROUND=1
export BASE_OUTPUT=/root/tb371fc-desktop-v56-4-kexec-drm-shutdown-out
export SOURCE=/root/tb371fc-desktop-v56-5-kexec-cpu-hotplug-src
export OUTPUT=/root/tb371fc-desktop-v56-5-kexec-cpu-hotplug-out
export RELEASE=/root/tb371fc-desktop-v56-5-kexec-cpu-hotplug-release
export BUILD_LOG=/root/tb371fc-v56-5-kexec-cpu-hotplug-build.log

exec bash "$PROJECT/scripts/build-v56-1-community-kernel.sh"
