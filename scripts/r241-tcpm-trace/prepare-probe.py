"""Keep all R238 safety gates; start read-only capture BEFORE TCPM probe."""
from pathlib import Path
import sys
source = Path(__file__).parent.parent/'r237-pd-integration/probe-r238.sh'
s = source.read_text()
anchor = 'insmod ./tcpm.ko\n'
assert s.count(anchor) == 1
prefix = '''# R241: establish sole log consumer before driver registration.
test ! -e /run/r238/trace-ready
systemd-run --unit=r241-trace --property=RuntimeMaxSec=90s /bin/sh /run/r238/collect-tcpm.sh
n=0
while [ ! -e /run/r238/trace-ready ]; do
    n=$((n+1)); [ "$n" -lt 30 ] || exit 1; sleep 0.1
done
'''
Path(sys.argv[1]).write_text(s.replace(anchor, prefix + anchor))
