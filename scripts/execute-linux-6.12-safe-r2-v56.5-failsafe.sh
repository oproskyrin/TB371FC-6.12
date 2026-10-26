#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
set -eu

approval=${1:-}
[ "$approval" = 'EXECUTE_VERIFIED_LINUX_6_12_SAFE_R2_FROM_V56_5' ] || {
	echo 'Exact execution token is required.' >&2
	exit 2
}
[ "$(uname -r)" = '4.19.157-perf-v56.5+' ] || {
	echo "unexpected source kernel: $(uname -r)" >&2
	exit 1
}

loader=/usr/local/sbin/tb371fc-load-linux-6.12-safe-r2-v56.5
module=/usr/local/lib/tb371fc/kexec-failsafe-bootloader-watchdog-v56.5.ko
expected_module_hash=00d587499331fd05eb15bea0799cbd288bab25f168492dfcd43a0b809e557bd7
kexec=/bin/kexec
[ -x "$kexec" ] || kexec=/run/tb371fc-rescue/kexec
[ -x "$kexec" ] || { echo 'kexec binary is unavailable' >&2; exit 1; }

[ -x "$loader" ] || { echo "missing loader: $loader" >&2; exit 1; }
[ -s "$module" ] || { echo "missing failsafe module: $module" >&2; exit 1; }
actual_module_hash=$(sha256sum "$module" | awk '{print $1}')
[ "$actual_module_hash" = "$expected_module_hash" ] || {
	echo 'failsafe module hash mismatch' >&2
	exit 1
}
if grep -q '^kexec_failsafe_bootloader_watchdog ' /proc/modules; then
	echo 'a kexec failsafe is already armed' >&2
	exit 1
fi

"$loader"
[ "$(cat /sys/kernel/kexec_loaded 2>/dev/null || true)" = 1 ] || {
	echo 'kernel did not report a loaded kexec image' >&2
	exit 1
}

stamp=$(date +%Y%m%d-%H%M%S 2>/dev/null || echo unknown-time)
log=/var/log/tb371fc-kexec-6.12-safe-r2-v56.5-$stamp.log
dmesg -w >"$log" 2>&1 &
insmod "$module" \
	authorization=ARM_VERIFIED_R7_KEXEC_FAILSAFE_TO_BOOTLOADER \
	timeout_sec=60
sync

set +e
"$kexec" -e
status=$?
set -e
echo "kexec returned with status $status; failsafe remains armed" >&2
while :; do sync; sleep 1; done
