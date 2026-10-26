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
text = text.replace('r64', 'r82')
expected_image = '/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r82-embedded-pgtable-pool/Image'
actual_image = '/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r82-pre-dt-allocator-autiasp-checkpoint/Image'
assert text.count(expected_image) == 1, 'r82 payload path anchor not unique'
text = text.replace(expected_image, actual_image)
old = '''Linux 6.12 payload: r82 embedded early page-table pool candidate fix plus
post-paging_init PSCI reset checkpoint; r57 DTB and proven Arch initramfs.'''
new = '''Linux 6.12 payload: r82 preserves the exact r70/r68 Image layout and
invokes PSCI reset immediately before autiasp in the successful epilogue of
early_init_dt_alloc_memory_arch(). No relinking; unchanged r57 DTB and proven
Arch initramfs.'''
assert text.count(old) == 1, 'r82 BUILD-INFO anchor not found or not unique'
text = text.replace(old, new)
open(dst, 'w', encoding='utf-8', newline='\n').write(text)
PYEOF
chmod 0755 "$generated"
bash "$generated"
