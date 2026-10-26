#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

output=${1:-/var/log/tb371fc-gpu-capture}
mkdir -p "$output"

run_capture() {
	local name=$1
	shift
	{
		echo "command: $*"
		timeout 20s "$@"
	} >"$output/$name.txt" 2>&1 || true
}

uname -a >"$output/uname.txt"
cat /proc/cmdline >"$output/cmdline.txt"
cat /proc/iomem >"$output/iomem.txt"
dmesg -T >"$output/dmesg.txt" 2>&1 || dmesg >"$output/dmesg.txt"
dmesg | grep -Ei 'drm|msm|dpu|dsi|adreno|a6xx|gmu|gpu|firmware|smmu|iommu|gpucc|opp|qfprom' \
	>"$output/dmesg-gpu-filtered.txt" || true
find /dev/dri -maxdepth 1 -ls >"$output/dev-dri.txt" 2>&1 || true
find /sys/class/drm -maxdepth 3 -type f -print -exec sh -c 'cat "$1" 2>/dev/null' sh {} \; \
	>"$output/sys-class-drm.txt" 2>&1 || true
find /sys/class/devfreq -maxdepth 3 -type f \( -name name -o -name governor -o -name cur_freq -o -name available_frequencies \) \
	-print -exec sh -c 'cat "$1" 2>/dev/null' sh {} \; >"$output/devfreq.txt" 2>&1 || true
for firmware in \
	/usr/lib/firmware/qcom/a650_sqe.fw \
	/usr/lib/firmware/qcom/a650_gmu.bin \
	/usr/lib/firmware/qcom/sm8250/lenovo/tb371fc/a650_zap.mbn; do
	sha256sum "$firmware" >>"$output/firmware-sha256.txt" 2>&1 || true
done

command -v modetest >/dev/null && run_capture modetest modetest -c -p -e
command -v eglinfo >/dev/null && run_capture eglinfo eglinfo -B
command -v glxinfo >/dev/null && run_capture glxinfo glxinfo -B
command -v vulkaninfo >/dev/null && run_capture vulkaninfo vulkaninfo --summary

tar -C "$(dirname "$output")" -czf "$output.tar.gz" "$(basename "$output")"
echo "$output.tar.gz"
