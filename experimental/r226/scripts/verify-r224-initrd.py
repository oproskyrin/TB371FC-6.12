"""Read-only archive comparison: reject unrelated changes to the working initrd."""
import gzip
from pathlib import Path
import sys

def entries(path):
    raw = gzip.decompress(Path(path).read_bytes())
    pos = 0
    result = {}
    while True:
        assert raw[pos:pos+6] == b'070701'
        fields = [int(raw[pos+6+i*8:pos+14+i*8], 16) for i in range(13)]
        pos += 110
        name = raw[pos:pos+fields[11]-1].decode()
        pos = (pos+fields[11]+3) & ~3
        data = raw[pos:pos+fields[6]]
        pos = (pos+fields[6]+3) & ~3
        if name == 'TRAILER!!!':
            return result
        while name.startswith('./'):
            name = name[2:]
        assert name not in result
        result[name] = (fields[1], data)

before, after = map(entries, sys.argv[1:3])
added = after.keys()-before.keys()
removed = before.keys()-after.keys()
changed = [name for name in before.keys() & after.keys() if before[name] != after[name]]
print(dict(added=sorted(added), removed=sorted(removed), changed=sorted(changed)))
assert added == {'usr/maint/r224-sd150-boot.ko'}
assert not removed
assert changed == ['bin/boot-arch-r129-base']
assert before['bin/boot-arch-r129-base'][0] == after['bin/boot-arch-r129-base'][0]
print('PASS: only the opt-in SD boot hook and its new module differ; all other initrd contents unchanged')
