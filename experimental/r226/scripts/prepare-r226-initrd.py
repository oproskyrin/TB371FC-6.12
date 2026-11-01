"""Package candidate-only runtime units in initrd; never install rootfs units."""
from pathlib import Path
import sys

stage = Path(sys.argv[1])
loader = stage / 'bin/boot-arch-r129-base'
data = loader.read_text()
anchor = 'mkdir -p /newroot/etc/systemd/system/timers.target.wants'
assert data.count(anchor) == 1
injection = '''# R226: runtime-only units survive /run move; ordinary R201 boot is untouched.
if grep -qw tb371fc.r226 /proc/cmdline; then
    mkdir -p /run/r226 /run/systemd/system/timers.target.wants
    cp /r226/* /run/r226/ || rescue 'R226 runtime payload copy failed'
    cp /r226/*.service /r226/*.timer /run/systemd/system/ || rescue 'R226 units copy failed'
    ln -s ../r226-touch-ready.timer /run/systemd/system/timers.target.wants/r226-touch-ready.timer || rescue 'R226 timer enable failed'
fi
'''
loader.write_text(data.replace(anchor, injection + anchor))
print('R226: runtime-only post-panel touch + opt-in USB3; existing root services unchanged')
