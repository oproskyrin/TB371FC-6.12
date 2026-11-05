"""Read only a bounded sample of the USB test disk; never mount or write it."""
import hashlib
import mmap
import os
from pathlib import Path
import time

assert 'tb371fc.r228' in Path('/proc/cmdline').read_text().split()
assert Path('/sys/class/block/sda/ro').read_text().strip() == '1'
assert Path('/sys/class/block/sda/size').read_text().strip() == '7831552'
assert 'usb' in str(Path('/sys/class/block/sda/device').resolve())
assert Path('/sys/kernel/debug/usb/a600000.usb/mode').read_text().strip() == 'host'
buffer = mmap.mmap(-1, 1024 * 1024)
results = []
try:
    for round_number in (1, 2):
        fd = os.open('/dev/sda', os.O_RDONLY | os.O_DIRECT)
        try:
            digest = hashlib.sha256()
            started = time.monotonic()
            for _ in range(32):
                assert os.readv(fd, [buffer]) == len(buffer)
                digest.update(buffer)
            elapsed = time.monotonic() - started
            results.append(digest.hexdigest())
            print(f'USB READ round={round_number} bytes=33554432 seconds={elapsed:.6f} MBps={33554432/elapsed/1e6:.2f} SHA256={results[-1]}', flush=True)
        finally:
            os.close(fd)
    assert results[0] == results[1], 'USB repeated read SHA mismatch'
    print('PASS: two direct USB reads match; no mount, no write, no persistent sample files')
finally:
    buffer.close()
