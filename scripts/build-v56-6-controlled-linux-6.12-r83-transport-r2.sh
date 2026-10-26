#!/usr/bin/env bash
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
template="$project/scripts/build-v56-6-controlled-linux-6.12-r82-transport-r2.sh"
template_sha=853b4b322fba2a4eb08bc50beb4eda8699540c06d12f919c1ffa9cb6e01db4cf
generated=$(mktemp)
trap 'rm -f -- "$generated"' EXIT

printf '%s  %s\n' "$template_sha" "$template" | sha256sum -c -
python3 - "$template" "$generated" <<'PYEOF'
import sys

src, dst = sys.argv[1:3]
text = open(src, encoding='utf-8').read()
assert text.count('r82') == 7, 'unexpected r82 transport template'
text = text.replace('r82', 'r83')
expected_image = '/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r83-pre-dt-allocator-autiasp-checkpoint/Image'
actual_image = '/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r83-dt-allocator-success-checkpoint/Image'
assert text.count(expected_image) == 1, 'r83 payload path anchor not unique'
text = text.replace(expected_image, actual_image)
old = '''Linux 6.12 payload: r83 preserves the exact r70/r68 Image layout and
invokes PSCI reset immediately before autiasp in the successful epilogue of
early_init_dt_alloc_memory_arch(). No relinking; unchanged r57 DTB and proven
Arch initramfs.'''
new = '''Linux 6.12 payload: r83 preserves the exact r70/r68 Image layout and
keeps the allocator NULL test intact. It invokes PSCI reset at the first
instruction reached only after a successful non-NULL DT allocation. No
relinking; unchanged r57 DTB and proven Arch initramfs.'''
assert text.count(old) == 1, 'r83 BUILD-INFO anchor not found or not unique'
text = text.replace(old, new)
open(dst, 'w', encoding='utf-8', newline='\n').write(text)
PYEOF
chmod 0755 "$generated"
bash "$generated"
