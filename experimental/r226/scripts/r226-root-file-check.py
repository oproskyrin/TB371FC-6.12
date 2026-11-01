"""Bounded, owned 64MiB ext4 file test; never raw block-device writes."""
import fcntl
import hashlib
import mmap
import os
from pathlib import Path
import re
import tempfile
import time

assert os.geteuid() == 0
assert 'tb371fc.sd150' in Path('/proc/cmdline').read_text().split()
ios = Path('/sys/kernel/debug/mmc0/ios').read_text()
assert re.search(r'actual clock:\s+150000000 Hz', ios)
assert Path('/sys/class/block/mmcblk0/device/cid').read_text().strip() == '1b534d45443253353044f46849a18800'

def errors():
    text = Path('/sys/kernel/debug/mmc0/err_stats').read_text()
    values = re.findall(r':\s*(\d+)', text)
    assert values and all(int(n) == 0 for n in values), text

errors()
size = 4 * 1024 * 1024
buffer = mmap.mmap(-1, size)
buffer[:] = os.urandom(size)
expected = hashlib.sha256()
for _ in range(16):
    expected.update(buffer)
fd, name = tempfile.mkstemp(prefix='r226-owned-64m-', dir='/var/tmp')
complete = False
try:
    fcntl.fcntl(fd, fcntl.F_SETFL, fcntl.fcntl(fd, fcntl.F_GETFL) | os.O_DIRECT)
    started = time.monotonic()
    for _ in range(16):
        assert os.write(fd, buffer) == size
    os.fsync(fd)
    write_s = time.monotonic() - started
    errors()
    os.lseek(fd, 0, os.SEEK_SET)
    actual = hashlib.sha256()
    started = time.monotonic()
    for _ in range(16):
        assert os.readv(fd, [buffer]) == size
        actual.update(buffer)
    read_s = time.monotonic() - started
    assert actual.digest() == expected.digest(), 'direct read SHA mismatch'
    errors()
    complete = True
    print(f'PASS 64MiB owned ext4 file: write={write_s:.6f}s read={read_s:.6f}s SHA256={actual.hexdigest()} all MMC errors=0')
finally:
    os.close(fd)
    buffer.close()
    if complete:
        os.unlink(name)
        print('Removed only the owned test file')
    else:
        print(f'FAIL: retained owned test file for investigation: {name}')
