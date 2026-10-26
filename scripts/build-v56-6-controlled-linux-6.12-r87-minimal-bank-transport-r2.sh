#!/usr/bin/env bash
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
template="$project/scripts/build-v56-6-controlled-linux-6.12-r64-transport-r2.sh"
template_sha=6bd966cd956850ddb9d65f702e8be9ebfc3e8788d5eba29ffd6361a93e964ca2
generated=$(mktemp)
trap 'rm -f -- "$generated"' EXIT

printf '%s  %s\n' "$template_sha" "$template" | sha256sum -c -
python3 - "$template" "$generated" <<'PYEOF'
import sys

src, dst = sys.argv[1:3]
text = open(src, encoding='utf-8').read()
assert text.count('r64') == 8, 'unexpected r64 transport template'
text = text.replace('r64', 'r87')
expected_image = '/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r87-embedded-pgtable-pool/Image'
actual_image = '/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r64-embedded-pgtable-pool/Image'
assert text.count(expected_image) == 1
text = text.replace(expected_image, actual_image)
expected_dtb = '/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r57-boot-log-region-reserved-dtb/sm8250-lenovo-tb371fc-archsafe-microsd.dtb'
actual_dtb = '/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r87-minimal-kexec-bank-dtb/sm8250-lenovo-tb371fc-archsafe-microsd-minimal-bank.dtb'
assert text.count(expected_dtb) == 1
text = text.replace(expected_dtb, actual_dtb)
old = '''Linux 6.12 payload: r87 embedded early page-table pool candidate fix plus
post-paging_init PSCI reset checkpoint; r57 DTB and proven Arch initramfs.'''
new = '''Linux 6.12 payload: exact r64 post-paging_init checkpoint Image plus an
r87 DTB advertising only the single 0x90500000..0x9bffffff System RAM bank
which contains every observed kexec segment. Automatic reset proves this bank
can be mapped and identifies a later r84 bank/workload as the r86 failure;
no reset localizes the fault to mapping the payload bank itself.'''
assert text.count(old) == 1
text = text.replace(old, new)
open(dst, 'w', encoding='utf-8', newline='\n').write(text)
PYEOF
chmod 0755 "$generated"
bash "$generated"

