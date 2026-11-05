"""Inject only /run payload; do not install persistent rootfs units."""
from pathlib import Path
import sys
stage = Path(sys.argv[1])
assert stage.name.startswith("r238-initrd.")
p = stage / "bin/boot-arch-r129-base"
s = p.read_text()
anchor = 'mkdir -p /newroot/etc/systemd/system/timers.target.wants'
assert s.count(anchor) == 1
hook = '''# R238: test modules staged in RAM, never automatically probed.
if grep -qw tb371fc.r238 /proc/cmdline; then
    grep -qw systemd.mask=r231-charge-keepalive.service /proc/cmdline || rescue 'R238 missing ownership mask'
    mkdir -p /run/r238
    cp /r238/* /run/r238/ || rescue 'R238 RAM payload copy failed'
fi
'''
p.write_text(s.replace(anchor, hook + anchor))
