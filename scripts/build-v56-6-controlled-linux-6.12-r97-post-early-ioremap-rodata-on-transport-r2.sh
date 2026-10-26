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
text = text.replace('r64', 'r97')

expected_image = '/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r97-embedded-pgtable-pool/Image'
actual_image = '/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r71-post-early-ioremap-checkpoint/Image'
assert text.count(expected_image) == 1, 'r97 Image path anchor not unique'
text = text.replace(expected_image, actual_image)

expected_dtb = '/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r57-boot-log-region-reserved-dtb/sm8250-lenovo-tb371fc-archsafe-microsd.dtb'
actual_dtb = '/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r84-real-ram-map-dtb/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram.dtb'
assert text.count(expected_dtb) == 1, 'r97 DTB path anchor not unique'
text = text.replace(expected_dtb, actual_dtb)

anchor = 'chmod 0755 "$stage/bin/load-linux-6.12-r38"\n'
replacement = anchor + '''sed -i \\
  "s/maxcpus=1 nr_cpus=1 reset_devices'/maxcpus=1 nr_cpus=1 reset_devices rodata=on'/" \\
  "$stage/bin/load-linux-6.12-r38"
grep -Fq 'reset_devices rodata=on' "$stage/bin/load-linux-6.12-r38"
'''
assert text.count(anchor) == 1, 'load-helper chmod anchor not unique'
text = text.replace(anchor, replacement)

old = '''Linux 6.12 payload: r97 embedded early page-table pool candidate fix plus
post-paging_init PSCI reset checkpoint; r57 DTB and proven Arch initramfs.'''
new = '''Linux 6.12 payload: exact r71 layout-preserving checkpoint Image,
which resets after unflatten_device_tree(), bootmem_init(),
request_standard_resources() and early_ioremap_reset(), before psci_dt_init().
It is paired with the full 19-range r84 real-RAM DTB and rodata=on. The
embedded 1 MiB early page-table pool and proven Arch initramfs are retained.'''
assert text.count(old) == 1, 'r97 BUILD-INFO anchor not unique'
text = text.replace(old, new)
open(dst, 'w', encoding='utf-8', newline='\n').write(text)
PYEOF
chmod 0755 "$generated"
bash "$generated"
