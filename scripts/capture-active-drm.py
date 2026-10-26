#!/usr/bin/env python3
"""Read active simpledrm scanout through DRM ioctls; no mode or register writes."""
import fcntl
import mmap
import os
import re
import struct
from pathlib import Path

state = Path('/sys/kernel/debug/dri/0/state').read_text()
match = re.search(r'\n\s*fb=(\d+)', state)
if not match:
    raise SystemExit('No active DRM framebuffer')
fb_id = int(match.group(1))
fd = os.open('/dev/dri/card0', os.O_RDWR | os.O_CLOEXEC)
handle = 0
try:
    fb = bytearray(104)
    struct.pack_into('I', fb, 0, fb_id)
    fcntl.ioctl(fd, 0xC06864CE, fb, True)  # DRM_IOCTL_MODE_GETFB2
    _, width, height, pixel_format, flags = struct.unpack_from('5I', fb)
    handle = struct.unpack_from('I', fb, 20)[0]
    pitch = struct.unpack_from('I', fb, 36)[0]
    offset = struct.unpack_from('I', fb, 52)[0]
    if not handle or pixel_format != int.from_bytes(b'XR24', 'little'):
        raise SystemExit('No readable XRGB8888 handle from GETFB2')
    if (width, height, pitch, offset) != (2944, 1840, 11776, 0):
        raise SystemExit(f'Unexpected layout: {width} {height} {pitch} {offset}')
    request = bytearray(struct.pack('IIQ', handle, 0, 0))
    fcntl.ioctl(fd, 0xC01064B3, request, True)  # DRM_IOCTL_MODE_MAP_DUMB
    map_offset = struct.unpack_from('Q', request, 8)[0]
    with mmap.mmap(fd, pitch * height, flags=mmap.MAP_SHARED,
                   prot=mmap.PROT_READ, offset=map_offset) as pixels:
        target = Path('/run/r131-active-scanout.bgrx')
        target.write_bytes(pixels[:])
    print(f'Captured fb={fb_id} {width}x{height} pitch={pitch}: {target}')
finally:
    if handle:
        fcntl.ioctl(fd, 0x40086409, struct.pack('II', handle, 0))  # GEM_CLOSE
    os.close(fd)
