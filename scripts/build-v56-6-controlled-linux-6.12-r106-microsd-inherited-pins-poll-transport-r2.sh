#!/usr/bin/env bash
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
template="$project/scripts/build-v56-6-controlled-linux-6.12-r104-sdhci-diagnostics-fwdevlink-off-transport-r2.sh"
generated=$(mktemp)
trap 'rm -f -- "$generated"' EXIT

bash "$project/scripts/build-linux-6.12-r106-headless-microsd-inherited-pins-poll-dtb.sh"

python3 - "$template" "$generated" <<'PYEOF'
import sys

src, dst = sys.argv[1:3]
text = open(src, encoding='utf-8').read()
assert text.count('r104') == 7, f'unexpected r104 anchor count: {text.count("r104")}'
text = text.replace('r104', 'r106')
assert text.count('R104') == 3, f'unexpected R104 anchor count: {text.count("R104")}'
text = text.replace('R104', 'R106')

old_dtb = '/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r101-headless-microsd-inherited-power-dtb/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram-ufs-disabled-no-usb1-mmc-inherited-power.dtb'
new_dtb = '/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r106-headless-microsd-inherited-pins-poll-dtb/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram-ufs-disabled-no-usb1-mmc-no-iommu-pio-inherited-pins-poll.dtb'
assert text.count(old_dtb) == 1, 'r106 DTB replacement anchor changed'
text = text.replace(old_dtb, new_dtb)

old_info = '''Linux 6.12 payload: exact r70 layout-preserving Image and exact r101
headless DTB. The second-stage command line contains exactly one fw_devlink=off
token and no permissive token. The r106 inner initramfs uses BusyBox tail and
discovers the actual 8804000.mmc sysfs path before reporting device links.'''
new_info = '''Linux 6.12 payload: exact r70 Image and r106 inherited-pin DTB.
The external microSD controller stays no-IOMMU/PIO-only; card-detect and pinctrl
GPIO dependencies are removed, inherited 4.19 pin state is retained, and
broken-cd enables safe polling. UFS and USB1 remain disabled.'''
assert text.count(old_info) == 1, 'r106 BUILD-INFO anchor changed'
text = text.replace(old_info, new_info)
open(dst, 'w', encoding='utf-8', newline='\n').write(text)
PYEOF
chmod 0755 "$generated"
bash "$generated"
