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
text = text.replace('r64', 'r95')

expected_image = '/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r95-embedded-pgtable-pool/Image'
actual_image = '/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r64-embedded-pgtable-pool/Image'
assert text.count(expected_image) == 1, 'r95 Image path anchor not unique'
text = text.replace(expected_image, actual_image)

expected_dtb = '/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r57-boot-log-region-reserved-dtb/sm8250-lenovo-tb371fc-archsafe-microsd.dtb'
actual_dtb = '/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r84-real-ram-map-dtb/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram.dtb'
assert text.count(expected_dtb) == 1, 'r95 DTB path anchor not unique'
text = text.replace(expected_dtb, actual_dtb)

anchor = 'chmod 0755 "$stage/bin/load-linux-6.12-r38"\n'
replacement = anchor + '''sed -i \
  "s/maxcpus=1 nr_cpus=1 reset_devices'/maxcpus=1 nr_cpus=1 reset_devices rodata=on'/" \
  "$stage/bin/load-linux-6.12-r38"
grep -Fq 'reset_devices rodata=on' "$stage/bin/load-linux-6.12-r38"
'''
assert text.count(anchor) == 1, 'load-helper chmod anchor not unique'
text = text.replace(anchor, replacement)

old = '''Linux 6.12 payload: r95 embedded early page-table pool candidate fix plus
post-paging_init PSCI reset checkpoint; r57 DTB and proven Arch initramfs.'''
new = '''Linux 6.12 payload: exact r64 post-paging_init checkpoint Image plus
the full 19-range r84 real-RAM DTB. The only runtime change is rodata=on,
which retains kernel read-only protection while disabling rodata_full's
page-granular linear map. The 7.1689 GiB map needs at least 3679 PTE-table
pages under rodata_full but r64 intentionally has only 256 embedded pages;
block mappings remove that deterministic exhaustion. Proven Arch initramfs.'''
assert text.count(old) == 1, 'r95 BUILD-INFO anchor not unique'
text = text.replace(old, new)
open(dst, 'w', encoding='utf-8', newline='\n').write(text)
PYEOF
chmod 0755 "$generated"
bash "$generated"
