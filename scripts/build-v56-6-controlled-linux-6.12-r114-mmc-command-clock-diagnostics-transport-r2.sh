#!/usr/bin/env bash
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
template="$project/scripts/build-v56-6-controlled-linux-6.12-r104-sdhci-diagnostics-fwdevlink-off-transport-r2.sh"
generated=$(mktemp)
trap 'rm -f -- "$generated"' EXIT
bash "$project/scripts/build-linux-6.12-r108-headless-microsd-redriver-hog-poll-dtb.sh"

python3 - "$template" "$generated" <<'PYEOF'
import sys
src, dst = sys.argv[1:3]
text = open(src, encoding='utf-8').read()
assert text.count('r104') == 7
text = text.replace('r104', 'r114')
assert text.count('R104') == 3
text = text.replace('R104', 'R114')
old_dtb = '/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r101-headless-microsd-inherited-power-dtb/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram-ufs-disabled-no-usb1-mmc-inherited-power.dtb'
new_dtb = '/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r108-headless-microsd-redriver-hog-poll-dtb/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram-ufs-disabled-no-usb1-mmc-no-iommu-pio-redriver-hog-poll.dtb'
assert text.count(old_dtb) == 1
text = text.replace(old_dtb, new_dtb)
old_info = '''Linux 6.12 payload: exact r70 layout-preserving Image and exact r101
headless DTB. The second-stage command line contains exactly one fw_devlink=off
token and no permissive token. The r114 inner initramfs uses BusyBox tail and
discovers the actual 8804000.mmc sysfs path before reporting device links.'''
new_info = '''Linux 6.12 payload: exact stable r108 Image/DTB hardware baseline.
r114 changes only initramfs diagnostics. It enables runtime MMC/SDHCI dynamic
debug when available, records mmc0 ios and SDCC2 clock rates, then safely
unbinds and rebinds the unused PIO host to expose the first command failure.
UFS/USB1 remain disabled and Android partitions are never mounted.'''
assert text.count(old_info) == 1
text = text.replace(old_info, new_info)
needle = "\\techo '=== R114 SDHCI DIAGNOSTICS END ===' >&2\n\\techo 'USB is intentionally disabled in this headless test.' >&2"
extra = '''	echo '--- R114 MMC COMMAND AND CLOCK TEST BEGIN ---' >&2
	mount -t debugfs debugfs /sys/kernel/debug 2>/dev/null || true
	if [ -w /sys/kernel/debug/dynamic_debug/control ]; then
		echo 'file drivers/mmc/core/* +p' > /sys/kernel/debug/dynamic_debug/control 2>/dev/null || true
		echo 'file drivers/mmc/host/* +p' > /sys/kernel/debug/dynamic_debug/control 2>/dev/null || true
	fi
	echo '--- initial mmc0 ios ---' >&2
	cat /sys/kernel/debug/mmc0/ios >&2 2>/dev/null || true
	echo '--- initial SDCC2 clocks ---' >&2
	grep -iE 'sdcc2|xo.board|xo_board' /sys/kernel/debug/clk/clk_summary >&2 2>/dev/null || true
	if [ -e /sys/bus/platform/drivers/sdhci_msm/8804000.mmc ]; then
		echo '--- unbind/rebind 8804000.mmc ---' >&2
		echo 8804000.mmc > /sys/bus/platform/drivers/sdhci_msm/unbind 2>/dev/null || true
		busybox sleep 1
		echo 8804000.mmc > /sys/bus/platform/drivers/sdhci_msm/bind 2>/dev/null || true
		busybox sleep 5
	fi
	dmesg -n 1 2>/dev/null || true
	echo '--- R114 post-rebind MMC/SDHCI dmesg ---' >&2
	dmesg 2>/dev/null | grep -iE 'mmc|sdhci|sdcc|timeout|timed out|crc|voltage|clock|reset' | busybox tail -n 100 >&2 || true
	echo '--- R114 final mmc0 ios ---' >&2
	cat /sys/kernel/debug/mmc0/ios >&2 2>/dev/null || true
	echo '--- R114 final SDCC2 clocks ---' >&2
	grep -iE 'sdcc2|xo.board|xo_board' /sys/kernel/debug/clk/clk_summary >&2 2>/dev/null || true
	echo '=== R114 MMC COMMAND AND CLOCK TEST END ===' >&2
	echo 'USB is intentionally disabled in this headless test.' >&2'''
assert text.count(needle) == 1
text = text.replace(needle, extra)
open(dst, 'w', encoding='utf-8', newline='\n').write(text)
PYEOF
chmod 0755 "$generated"
bash "$generated"
