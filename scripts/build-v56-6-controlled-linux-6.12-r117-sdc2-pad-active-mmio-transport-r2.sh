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
text = text.replace('r104', 'r117')
assert text.count('R104') == 3
text = text.replace('R104', 'R117')
old_dtb = '/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r101-headless-microsd-inherited-power-dtb/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram-ufs-disabled-no-usb1-mmc-inherited-power.dtb'
new_dtb = '/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r108-headless-microsd-redriver-hog-poll-dtb/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram-ufs-disabled-no-usb1-mmc-no-iommu-pio-redriver-hog-poll.dtb'
assert text.count(old_dtb) == 1
text = text.replace(old_dtb, new_dtb)
old_info = '''Linux 6.12 payload: exact r70 layout-preserving Image and exact r101
headless DTB. The second-stage command line contains exactly one fw_devlink=off
token and no permissive token. The r117 inner initramfs uses BusyBox tail and
discovers the actual 8804000.mmc sysfs path before reporting device links.'''
new_info = '''Linux 6.12 payload: exact stable r108 Image/DTB hardware baseline.
r117 changes only rescue diagnostics. It restores the Qualcomm Kona/SM8250
SDC2 CLK/CMD/DATA pad-control register to the exact Lenovo 4.19 active state
(16-mA drive, CMD/DATA pull-ups), rebinds SDHCI and reports enumeration.
UFS/USB1 stay off; Android is never mounted.'''
assert text.count(old_info) == 1
text = text.replace(old_info, new_info)
needle = "\\techo '=== R117 SDHCI DIAGNOSTICS END ===' >&2\n\\techo 'USB is intentionally disabled in this headless test.' >&2"
extra = '''\techo '--- R117 SDC2 PAD ACTIVE MMIO BEGIN ---' >&2
\tsdc2_pad_addr=0xF9B7000
\tsdc2_before=$(busybox devmem "$sdc2_pad_addr" 32 2>/dev/null || true)
\techo "SDC2_PAD_BEFORE=$sdc2_before" >&2
\tif [ -e /sys/bus/platform/drivers/sdhci_msm/8804000.mmc ]; then
\t\techo 8804000.mmc > /sys/bus/platform/drivers/sdhci_msm/unbind 2>/dev/null || true
\t\tbusybox sleep 1
\tfi
\tcase "$sdc2_before" in
\t\t0x*|0X*) sdc2_value=$((sdc2_before));;
\t\t*) sdc2_value=-1;;
\tesac
\tif [ "$sdc2_value" -ge 0 ] 2>/dev/null; then
\t\t# Kona 4.19 sdc2 active: CLK no-pull/16mA, CMD+DATA pull-up/16mA.
\t\t# These three fields occupy bits 0..12 and encode exactly as 0x1fff.
\t\tsdc2_active=$(((sdc2_value & ~0x1fff) | 0x1fff))
\t\tbusybox devmem "$sdc2_pad_addr" 32 "$sdc2_active" >/dev/null 2>&1 || true
\t\tbusybox sleep 1
\t\techo "SDC2_PAD_ACTIVE=$(busybox devmem "$sdc2_pad_addr" 32 2>/dev/null || true)" >&2
\tfi
\techo 8804000.mmc > /sys/bus/platform/drivers/sdhci_msm/bind 2>/dev/null || true
\tbusybox sleep 10
\tdmesg -n 1 2>/dev/null || true
\techo '--- R117 post-pad-restore MMC result ---' >&2
\tdmesg 2>/dev/null | grep -iE 'mmc0|mmcblk|sdhci|timeout|timed out|crc|ED2S5' | busybox tail -n 120 >&2 || true
\tls -la /sys/class/mmc_host/mmc0 >&2 2>/dev/null || true
\tls -la /sys/block/mmcblk* >&2 2>/dev/null || true
\techo '=== R117 SDC2 PAD ACTIVE MMIO END ===' >&2
\techo 'USB is intentionally disabled in this headless test.' >&2'''
assert text.count(needle) == 1
text = text.replace(needle, extra)
open(dst, 'w', encoding='utf-8', newline='\n').write(text)
PYEOF
chmod 0755 "$generated"
bash "$generated"
