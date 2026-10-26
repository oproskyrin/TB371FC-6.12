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
text = text.replace('r98', 'r100')

old_dtb = '/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r100-ufs-disabled-dtb/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram-ufs-disabled.dtb'
new_dtb = '/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r100-headless-microsd-no-rpmh-opp-dtb/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram-ufs-disabled-no-usb1-no-mmc-rpmh-opp.dtb'
assert text.count(old_dtb) == 1, 'r100 DTB path anchor not unique'
text = text.replace(old_dtb, new_dtb)

old = '''Linux 6.12 payload: exact r70 layout-preserving full-boot Image,
full 19-range real-RAM DTB with only UFS host and PHY disabled, and rodata=on.
This preserves the r95-proven paging path while removing the r96 UFS/OPP
-EPROBE_DEFER storm. Internal Android UFS is neither required nor accessed.
The embedded 1 MiB early page-table pool and Arch initramfs are retained.'''
new = '''Linux 6.12 payload: exact r70 layout-preserving full-boot Image,
full 19-range real-RAM DTB with UFS and USB1 disabled, plus the r100 SDHCI
headless fix that removes only its unavailable RPMh power-domain/OPP links.
r99 already proved complete kernel/initramfs boot; r100 tests persistent Arch
root discovery while retaining conservative 25 MHz 3.3-V-only microSD wiring.
The embedded 1 MiB early page-table pool and rodata=on are retained.'''
assert text.count(old) == 1, 'r100 BUILD-INFO anchor not unique'
text = text.replace(old, new)
open(dst, 'w', encoding='utf-8', newline='\n').write(text)
PYEOF
chmod 0755 "$generated"
bash "$generated"
