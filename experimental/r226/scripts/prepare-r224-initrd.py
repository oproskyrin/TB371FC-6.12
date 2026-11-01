"""Mechanical generated-initrd change: opt-in150MHz guarded PRE-root transition."""
from pathlib import Path
import sys

stage = Path(sys.argv[1])
loader = stage / 'bin/boot-arch-r129-base'
data = loader.read_text()
start = data.index('            "$bb" insmod /usr/maint/tb371fc-uhs.ko ')
end = data.index('\n', start)
original = data[start:end]
assert data.count(original) == 1
replacement = '''            if grep -qw tb371fc.sd150 /proc/cmdline; then
                "$bb" blockdev --setro /dev/mmcblk0 || rescue 'R224 cannot protect SD before timing change'
                "$bb" insmod /usr/maint/r224-sd150-boot.ko || rescue 'R224150MHz transition failed; no root writes'
                grep -q 'actual clock:.*150000000 Hz' /sys/kernel/debug/mmc0/ios || rescue 'R224150MHz not confirmed'
                "$bb" blockdev --setrw /dev/mmcblk0 || rescue 'R224 cannot release SD read-only after validation'
                echo 'R224: SDR104150MHz verified before root mount'
            else
''' + original + '''
            fi'''
loader.write_text(data[:start] + replacement + data[end:])
assert 'tb371fc.sd150' in loader.read_text()
print('R224 initrd: only opt-in pre-root SD transition changed; normal path retained')
