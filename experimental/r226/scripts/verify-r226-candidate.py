"""Ensure the combined candidate keeps all unrelated initrd payloads intact."""
import sys
from pathlib import Path

# Reuse the independently tested archive parser without executing its CLI.
source = (Path(__file__).with_name('verify-r224-initrd.py')).read_text()
namespace = {}
exec(source.split('before, after =')[0], namespace)
before, after = map(namespace['entries'], sys.argv[1:3])
added = after.keys() - before.keys()
changed = {n for n in before.keys() & after.keys() if before[n] != after[n]}
assert not before.keys() - after.keys()
assert changed == {'bin/boot-arch-r129-base'}, changed
expected = {'r226', *('r226/' + n for n in (
    'r225-touch-pm.ko', 'r209-qmp.ko', 'r207-ps5169.ko',
    'aux-hpd-bridge.ko', 'r203-usb-regulators.ko',
    'r226-touch-ready.sh', 'r226-touch-ready.service', 'r226-touch-ready.timer',
    'r226-usb3-ready.sh', 'r226-usb3-ready.service', 'r203-retry-usb-gadget.sh'))}
assert added == expected, sorted(added)
print('PASS: only runtime-unit staging hook and the declared R226 files added')
