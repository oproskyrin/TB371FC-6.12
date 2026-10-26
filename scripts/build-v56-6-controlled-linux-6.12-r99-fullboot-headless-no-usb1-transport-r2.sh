#!/usr/bin/env bash
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
template="$project/scripts/build-v56-6-controlled-linux-6.12-r98-fullboot-ufs-disabled-transport-r2.sh"
template_sha=$(sha256sum "$template" | awk '{print $1}')
generated=$(mktemp)
trap 'rm -f -- "$generated"' EXIT

printf '%s  %s\n' "$template_sha" "$template" | sha256sum -c -
python3 - "$template" "$generated" <<'PYEOF'
import sys

src, dst = sys.argv[1:3]
text = open(src, encoding='utf-8').read()
assert text.count('r98') == 7, f'unexpected r98 anchor count: {text.count("r98")}'
text = text.replace('r98', 'r99')

old_dtb = '/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r99-ufs-disabled-dtb/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram-ufs-disabled.dtb'
new_dtb = '/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r99-headless-no-usb1-dtb/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram-ufs-disabled-no-usb1.dtb'
assert text.count(old_dtb) == 1, 'r99 DTB path anchor not unique'
text = text.replace(old_dtb, new_dtb)

old = '''Linux 6.12 payload: exact r70 layout-preserving full-boot Image,
full 19-range real-RAM DTB with only UFS host and PHY disabled, and rodata=on.
This preserves the r95-proven paging path while removing the r96 UFS/OPP
-EPROBE_DEFER storm. Internal Android UFS is neither required nor accessed.
The embedded 1 MiB early page-table pool and Arch initramfs are retained.'''
new = '''Linux 6.12 payload: exact r70 layout-preserving full-boot Image,
full 19-range real-RAM DTB with UFS host/PHY and USB1 wrapper disabled, and
rodata=on. r98 removed the UFS storm and exposed a new dwc3 a600000 IOMMU
group-8 reprobe storm. r99 is the controlled headless milestone that removes
that loop so initramfs/userspace can be reached before USB is repaired.
The embedded 1 MiB early page-table pool and Arch initramfs are retained.'''
assert text.count(old) == 1, 'r99 BUILD-INFO anchor not unique'
text = text.replace(old, new)
open(dst, 'w', encoding='utf-8', newline='\n').write(text)
PYEOF
chmod 0755 "$generated"
bash "$generated"
