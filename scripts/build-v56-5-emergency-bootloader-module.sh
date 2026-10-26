#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

PROJECT=${PROJECT:-<repo>}
export PROJECT BUILD_VERSION=56.5 BUILD_SLUG=56-5
export SOURCE=/root/tb371fc-desktop-v56-5-kexec-cpu-hotplug-src
export OUTPUT=/root/tb371fc-desktop-v56-5-kexec-cpu-hotplug-out
export RELEASE=/root/tb371fc-desktop-v56-5-kexec-cpu-hotplug-release
export MODULE_DIR=/root/tb371fc-v56-5-emergency-bootloader-module

exec bash "$PROJECT/scripts/build-v56-3-emergency-bootloader-module.sh"
