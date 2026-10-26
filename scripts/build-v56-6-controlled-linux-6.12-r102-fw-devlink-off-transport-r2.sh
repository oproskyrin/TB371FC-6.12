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
text = text.replace('r98', 'r102')

old_dtb = '/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r102-ufs-disabled-dtb/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram-ufs-disabled.dtb'
new_dtb = '/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r101-headless-microsd-inherited-power-dtb/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram-ufs-disabled-no-usb1-mmc-inherited-power.dtb'
assert text.count(old_dtb) == 1, 'r102 DTB path anchor not unique'
text = text.replace(old_dtb, new_dtb)

old_cmdline = 'reset_devices rodata=on'
new_cmdline = 'reset_devices rodata=on fw_devlink=off'
assert text.count(old_cmdline) == 2, 'r102 command-line anchors changed'
text = text.replace(old_cmdline, new_cmdline)

old = '''Linux 6.12 payload: exact r70 layout-preserving full-boot Image,
full 19-range real-RAM DTB with only UFS host and PHY disabled, and rodata=on.
This preserves the r95-proven paging path while removing the r96 UFS/OPP
-EPROBE_DEFER storm. Internal Android UFS is neither required nor accessed.
The embedded 1 MiB early page-table pool and Arch initramfs are retained.'''
new = '''Linux 6.12 payload: exact r70 layout-preserving full-boot Image and
the exact r101 headless DTB. The only delta from r101 is fw_devlink=off on
the kexec command line. It bypasses automatic DT supplier gating so SDHCI
either probes using inherited resources or prints the exact reset/clock
failure returned by its driver. UFS and USB1 remain disabled; microSD stays
at 25 MHz, four-bit, no-1.8-V with inherited card rails and fixed board XO.'''
assert text.count(old) == 1, 'r102 BUILD-INFO anchor not unique'
text = text.replace(old, new)
open(dst, 'w', encoding='utf-8', newline='\n').write(text)
PYEOF
chmod 0755 "$generated"
bash "$generated"
