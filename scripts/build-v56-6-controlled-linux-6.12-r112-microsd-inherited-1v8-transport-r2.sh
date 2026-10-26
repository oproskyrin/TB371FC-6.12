#!/usr/bin/env bash
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
template="$project/scripts/build-v56-6-controlled-linux-6.12-r104-sdhci-diagnostics-fwdevlink-off-transport-r2.sh"
generated=$(mktemp)
trap 'rm -f -- "$generated"' EXIT
bash "$project/scripts/build-linux-6.12-r112-headless-microsd-inherited-1v8-dtb.sh"

python3 - "$template" "$generated" <<'PYEOF'
import sys
src, dst = sys.argv[1:3]
text = open(src, encoding='utf-8').read()
assert text.count('r104') == 7
text = text.replace('r104', 'r112')
assert text.count('R104') == 3
text = text.replace('R104', 'R112')
old_dtb = '/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r101-headless-microsd-inherited-power-dtb/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram-ufs-disabled-no-usb1-mmc-inherited-power.dtb'
new_dtb = '/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r112-headless-microsd-inherited-1v8-dtb/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram-ufs-disabled-no-usb1-mmc-no-iommu-pio-redriver-hog-inherited-1v8.dtb'
assert text.count(old_dtb) == 1
text = text.replace(old_dtb, new_dtb)
old_info = '''Linux 6.12 payload: exact r70 layout-preserving Image and exact r101
headless DTB. The second-stage command line contains exactly one fw_devlink=off
token and no permissive token. The r112 inner initramfs uses BusyBox tail and
discovers the actual 8804000.mmc sysfs path before reporting device links.'''
new_info = '''Linux 6.12 payload: exact r70 Image and r112 inherited-1.8-V DTB.
Only the contradictory no-1-8-v property is removed from the r108 MMC baseline
to match the measured 1.808-V I/O state left by the working 4.19 first stage.
PIO-only, 25 MHz, GPIO75 hog, UFS-off and USB1-off safety remain unchanged.'''
assert text.count(old_info) == 1
text = text.replace(old_info, new_info)
open(dst, 'w', encoding='utf-8', newline='\n').write(text)
PYEOF
chmod 0755 "$generated"
bash "$generated"
