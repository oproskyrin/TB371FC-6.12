"""Derive test cmdline from SUCCESSFUL R234 launcher, never donor DT bootargs."""
from pathlib import Path
import re
import subprocess
import sys
source = Path(__file__).with_name('r234-boot-test.sh').read_text()
matches = re.findall(r"^cmdline='([^']+)'$", source, re.M)
assert len(matches) == 1
tokens = matches[0].split()
assert tokens.count('tb371fc.r234') == 1
tokens[tokens.index('tb371fc.r234')] = 'tb371fc.r238'
tokens.extend(['tb371fc.r237', 'systemd.mask=r231-charge-keepalive.service'])
required = {'console=tty0','rdinit=/init','root=/dev/ram0','fw_devlink=off',
            'regulator_ignore_unused','reset_devices','tb371fc.sd150',
            'tb371fc.r226','tb371fc.usb3test','tb371fc.r238',
            'systemd.mask=r231-charge-keepalive.service'}
assert required <= set(tokens)
assert 'fw_devlink=permissive' not in tokens
line = ' '.join(tokens)
subprocess.run(['fdtput','-t','s',sys.argv[1],'/chosen','bootargs',line], check=True)
Path(sys.argv[2]).write_text(line+'\n')
print('PASS: full proven R234 cmdline retained, only test marker + R231 mask added')
