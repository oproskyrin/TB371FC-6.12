"""Parse the LP (dynamic partitions) metadata printed by r190-super-meta-419.sh (od hex)."""
import struct, sys
data = bytearray()
for line in open(sys.argv[1], encoding='utf-8', errors='replace'):
    if line.startswith('HEX '):
        parts = line.split()[2:]
        data += bytes(int(x, 16) for x in parts)
geo = data[0:4096]
magic, size = struct.unpack_from('<II', geo, 0)
mms, slots, lbs = struct.unpack_from('<III', geo, 40)
print(f'geometry magic {magic:#x} metadata_max {mms} slots {slots} block {lbs}')
h = 8192  # primary metadata slot 0 (after geometry + backup geometry)
m, maj, mnr, hsz = struct.unpack_from('<IHHI', data, h)
tables_size = struct.unpack_from('<I', data, h + 44)[0]
pd = struct.unpack_from('<III', data, h + 80); ed = struct.unpack_from('<III', data, h + 92)
print(f'header magic {m:#x} v{maj}.{mnr} header_size {hsz} tables {tables_size} parts {pd} extents {ed}')
t = h + hsz
exts = [struct.unpack_from('<QIQI', data, t + ed[0] + i * ed[2]) for i in range(ed[1])]
for i in range(pd[1]):
    name, attr, fe, ne, grp = struct.unpack_from('<36sIIII', data, t + pd[0] + i * pd[2])
    name = name.rstrip(b'\0').decode()
    ex = exts[fe:fe + ne]
    desc = ', '.join(f'{e[0]} sectors @ {e[2]} (type {e[1]})' for e in ex)
    print(f'{name:16s} extents={ne} {desc}')
