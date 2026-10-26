#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
set -eu

[ "${1:-}" = 'EXECUTE_VERIFIED_LINUX_6_12_DIAG39_R1' ] || {
	echo 'Exact execution token is required.' >&2; exit 2;
}
[ "$(uname -r)" = '4.19.157-perf-v56.5+' ] || {
	echo "unexpected source kernel: $(uname -r)" >&2; exit 1;
}

kexec=/bin/kexec
[ -x "$kexec" ] || kexec=/run/tb371fc-rescue/kexec
loader=/usr/local/sbin/tb371fc-load-linux-6.12-diag39-r1
module=/usr/local/lib/tb371fc/kexec-failsafe-bootloader-watchdog-v56.5.ko
[ -x "$kexec" ] && [ -x "$loader" ] && [ -s "$module" ] || exit 1
[ "$(sha256sum "$module" | awk '{print $1}')" = '00d587499331fd05eb15bea0799cbd288bab25f168492dfcd43a0b809e557bd7' ] || exit 1
! grep -q '^kexec_failsafe_bootloader_watchdog ' /proc/modules || exit 1

"$loader"
[ "$(cat /sys/kernel/kexec_loaded)" = 1 ] || exit 1
insmod "$module" authorization=ARM_VERIFIED_R7_KEXEC_FAILSAFE_TO_BOOTLOADER timeout_sec=60
sync
"$kexec" -e
while :; do sync; sleep 1; done
