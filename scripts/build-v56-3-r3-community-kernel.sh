#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# V56.3-r3: preserve the proven bridge kernel and add QCA6390 HCI UART support.
set -euo pipefail

PROJECT=${PROJECT:-<repo>}
export PROJECT
export BUILD_VERSION=56.3
export BUILD_SLUG=56-3-r3
export ENABLE_FHANDLE=1
export ENABLE_KEXEC=1
export ENABLE_BT_HCIUART=1
export BASE_SOURCE=/root/tb371fc-desktop-v56-3-kexec-src
export BASE_OUTPUT=/root/tb371fc-desktop-v56-3-kexec-out
export SOURCE=/root/tb371fc-desktop-v56-3-r3-src
export OUTPUT=/root/tb371fc-desktop-v56-3-r3-out
export RELEASE=/root/tb371fc-desktop-v56-3-r3-release
export BUILD_LOG=/root/tb371fc-v56-3-r3-build.log

exec bash "$PROJECT/scripts/build-v56-1-community-kernel.sh"
