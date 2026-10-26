#!/usr/bin/env bash
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
base_source=/root/tb371fc-desktop-v56-5-kexec-cpu-hotplug-src
base_output=/root/tb371fc-desktop-v56-5-kexec-cpu-hotplug-out
source=/root/tb371fc-desktop-v56-6-watchdog-kexec-src
output=/root/tb371fc-desktop-v56-6-watchdog-kexec-out
release=/root/tb371fc-desktop-v56-6-watchdog-kexec-release
patch="$project/vendor-kernel/patches/0027-msm-watchdog-local-kexec-shutdown.patch"

test -d "$base_source/.git"
test -s "$base_output/.config"
test -s "$patch"
if [ ! -d "$source/.git" ]; then
	test ! -e "$source"
	cp -a --reflink=auto "$base_source" "$source"
fi
if [ ! -s "$output/.config" ]; then
	mkdir -p "$output"
	cp "$base_output/.config" "$output/.config"
fi
if ! grep -Fq 'MSM Watchdog disabled for shutdown/kexec' "$source/drivers/soc/qcom/watchdog_v2.c"; then
	git -C "$source" apply --check "$patch"
	git -C "$source" apply "$patch"
fi

PROJECT="$project" BUILD_VERSION=56.6 BUILD_SLUG=56-6 \
	ENABLE_FHANDLE=1 ENABLE_KEXEC=1 \
	ENABLE_KEXEC_DRM_SHUTDOWN_WORKAROUND=1 \
	ENABLE_KEXEC_CPU_HOTPLUG_WORKAROUND=1 \
	BASE_OUTPUT="$base_output" SOURCE="$source" OUTPUT="$output" \
	RELEASE="$release" BUILD_LOG=/root/tb371fc-v56-6-watchdog-kexec-build.log \
	bash "$project/scripts/build-v56-1-community-kernel.sh"

grep -Fq 'disabling the local APSS watchdog for kexec' "$source/drivers/soc/qcom/watchdog_v2.c"
grep -Fq '.shutdown = msm_watchdog_shutdown' "$source/drivers/soc/qcom/watchdog_v2.c"
