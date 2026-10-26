#!/usr/bin/env python3
"""Repackage audited r120 with observable first-kernel panic and durable logs.

This is a diagnostic candidate, not a claim of successful Linux 6.12 boot.
"""
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

project = Path(__file__).resolve().parent.parent
builds = Path('/mnt/d/TB371FC-builds')
source = builds/'linux-6.12.30-tb371fc-r120-handoff-20261001/tb371fc-r120-recovery.img'
output = builds/'linux-6.12.30-tb371fc-r121-panic-gate-20261023'
unpack = '/root/mkbootimg/unpack_bootimg.py'
avb = '/root/avb/avbtool.py'
stock = project/'artifacts/device-backup/lun0-recovery_b.bin'

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def run(*args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)

assert digest(source) == '64c6289b870fd91a91c0c569965d2992f99d3c81a2812ae72991343efc073f99'
output.mkdir(exist_ok=False)
with tempfile.TemporaryDirectory(prefix='tb371fc-r121-') as temp:
    tmp = Path(temp)
    info = subprocess.check_output(['python3', unpack, '--boot_img', str(source), '--out', str(tmp)], text=True)
    stage = tmp/'stage'
    stage.mkdir()
    run('bash', '-o', 'pipefail', '-c', 'gzip -dc "$1" | cpio -idmu', 'unpack', str(tmp/'ramdisk'), cwd=stage, stderr=subprocess.DEVNULL)
    payload = stage/'opt/tb371fc-linux-6.12-r38'
    original = {name: digest(payload/name) for name in ('Image', 'board.dtb', 'initramfs.cpio.gz')}
    execute = stage/'bin/execute-linux-6.12-r38'
    text = execute.read_text().replace('R120 HANDOFF', 'R121 HANDOFF').replace('tb371fc-r120-handoff.log', 'tb371fc-r121-handoff.log')
    anchor = 'mark "entered; kernel='
    assert text.count(anchor) == 1
    text = text.replace(anchor, '''# The first kernel previously had panic=-1, hiding shutdown panics.
echo 0 >/proc/sys/kernel/panic
[ "$(cat /proc/sys/kernel/panic)" = 0 ] || exit 1
mark "first-stage panic=$(cat /proc/sys/kernel/panic)"
mark "entered; kernel=''', 1)
    anchor = 'mark \'calling kexec -e\''
    assert text.count(anchor) == 1
    text = text.replace(anchor, '''# /var/log is on the verified microSD loop-root, not Android storage.
case "$(uname -r)" in 4.19*) ;; *) mark 'unexpected first kernel'; exit 1 ;; esac
if [ -f /etc/tb371fc-development-image ]; then
    evidence=/var/log/tb371fc-r121
    mkdir -p "$evidence"
    bootid=$(cat /proc/sys/kernel/random/boot_id)
    cp "$log" "$evidence/$bootid-before-execute.log"
    cp /run/tb371fc-r121-handoff.log "$evidence/$bootid-handoff.log"
    "$bb" dmesg >"$evidence/$bootid-dmesg.log"
    sync
    mark "persistent evidence saved: $evidence/$bootid-*"
fi
mark 'calling kexec -e' ''')
    execute.write_text(text)
    run('sh', '-n', str(execute))
    for name, value in original.items():
        assert digest(payload/name) == value
    ramdisk = output/'r121.cpio.gz'
    with ramdisk.open('wb') as stream:
        run('bash', '-o', 'pipefail', '-c', 'find . -print0 | sort -z | cpio --null -o --format=newc --owner=0:0 | gzip -9n', cwd=stage, stdout=stream)
    for name in ('kernel', 'dtb', 'recovery_dtbo'):
        shutil.copyfile(tmp/name, output/name)
    cmdlines = [line.split(':', 1)[1].strip() for line in info.splitlines() if line.startswith('command line args:')]
    assert len(cmdlines) == 1 and 'panic=-1' in cmdlines[0]
    cmdline = cmdlines[0].replace('panic=-1', 'panic=0')
    env = dict(os.environ, RECOVERY_DTBO=str(output/'recovery_dtbo'), DIAGNOSTIC_CMDLINE=cmdline)
    image = output/'tb371fc-r121-recovery.img'
    run('bash', str(project/'scripts/build-diagnostic-recovery.sh'), '/root/mkbootimg/mkbootimg.py', unpack, avb, str(stock), str(output/'kernel'), str(ramdisk), str(output/'dtb'), str(image), env=env)
    with (output/'audit.log').open('w') as report:
        run('bash', str(project/'scripts/verify-diagnostic-recovery.sh'), unpack, avb, str(image), str(stock), str(output/'kernel'), str(ramdisk), str(output/'dtb'), digest(image), env=env, stdout=report, stderr=subprocess.STDOUT)
    shutil.copyfile(execute, output/'execute-linux-6.12-r38')
    (output/'BUILD-INFO.txt').write_text('R121: r120 kernel/DT/payload preserved. First-stage panic=0; durable pre-handoff evidence.\nHardware not yet tested; not a stable release.\n'+str(original)+'\n')
    (output/'SHA256SUMS').write_text(''.join(f'{digest(p)}  {p.name}\n' for p in sorted(output.iterdir()) if p.is_file()))
    print('AUDIT_RESULT=PASS', image, digest(image), flush=True)
