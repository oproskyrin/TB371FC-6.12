"""Verify declared RAM-only differences; no unrelated initrd changes allowed."""
from pathlib import Path
import sys
ns = {}
exec(Path(__file__).with_name('verify-r224-initrd.py').read_text().split('before, after =')[0], ns)
before, after = map(ns['entries'], sys.argv[1:3])
assert not before.keys() - after.keys()
changed = {n for n in before.keys() & after.keys() if before[n] != after[n]}
assert changed == {'bin/boot-arch-r129-base', 'r226/r203-usb-regulators.ko'}, changed
added = after.keys() - before.keys()
expected = {'r238', 'r238/tcpm.ko', 'r238/r233_pmic_tcpm.ko',
                 'r238/r235-watchdog-only.ko', 'r238/SHA256SUMS',
                 'r238/probe-r238.sh'} | set(sys.argv[3:])
assert added == expected, added
for n in changed:
    assert before[n][0] == after[n][0], n
assert b'systemd.mask=r231-charge-keepalive.service' in after['bin/boot-arch-r129-base'][1]
print(f'PASS: only declared provider/hook changes and{len(expected)} R238 entries; all other files/modes unchanged')
