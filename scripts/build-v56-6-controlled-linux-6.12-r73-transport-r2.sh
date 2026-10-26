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
text = text.replace('r64', 'r73')
expected_image = '/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r73-embedded-pgtable-pool/Image'
actual_image = '/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r73-post-unflatten-checkpoint/Image'
assert text.count(expected_image) == 1, 'r73 payload path anchor not unique'
text = text.replace(expected_image, actual_image)
old = '''Linux 6.12 payload: r73 embedded early page-table pool candidate fix plus
post-paging_init PSCI reset checkpoint; r57 DTB and proven Arch initramfs.'''
new = '''Linux 6.12 payload: r73 preserves the exact r70/r68 Image layout and
invokes PSCI reset after unflatten_device_tree() returns, immediately before
bootmem_init(). No relinking; unchanged r57 DTB and proven Arch initramfs.'''
assert text.count(old) == 1, 'r73 BUILD-INFO anchor not found or not unique'
text = text.replace(old, new)
open(dst, 'w', encoding='utf-8', newline='\n').write(text)
PYEOF
chmod 0755 "$generated"
bash "$generated"
