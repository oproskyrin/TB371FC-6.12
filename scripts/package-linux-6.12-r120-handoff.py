#!/usr/bin/env python3
"""Package an instrumented r118 payload with the verified r101 USB runtime.

Run in Ubuntu-24.04. Never overwrites an existing output directory.
"""
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

project = Path(__file__).resolve().parent.parent
builds = Path('/mnt/d/TB371FC-builds')
output = builds / 'linux-6.12.30-tb371fc-r120-handoff-20261001'
unpack = '/root/mkbootimg/unpack_bootimg.py'
avb = '/root/avb/avbtool.py'

def run(*args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def source(rev, expected):
    folder = builds / f'linux-6.12.30-tb371fc-v56.6-controlled-kexec-r{rev}-transport-r2'
    image = folder / f'tb371fc-v56.6-controlled-linux-6.12-r{rev}-transport-r2-recovery.img'
    assert digest(image) == expected, f'r{rev} source hash mismatch'
    return image

src118 = source(118, '67e04f7369eccf1118874c7ec0d7aa4f57c9e020002801783d9008f9bd740b8d')
src101 = source(101, 'f21938add6495043e5cfcc9bcc13bdcc385aa2637541e251b1434fd9f0a746c1')
output.mkdir(exist_ok=False)
with tempfile.TemporaryDirectory(prefix='tb371fc-r120-') as temporary:
    tmp = Path(temporary)
    for rev, image in ((118, src118), (101, src101)):
        dst = tmp / str(rev)
        run('python3', unpack, '--boot_img', str(image), '--out', str(dst), stdout=subprocess.DEVNULL)
        stage = dst / 'stage'
        stage.mkdir()
        run('bash', '-o', 'pipefail', '-c', 'gzip -dc "$1" | cpio -idmu', 'unpack', str(dst/'ramdisk'), cwd=stage, stderr=subprocess.DEVNULL)
    base = tmp/'118'
    stage = base/'stage'
    runtime = Path('bin/tb371fc-development-init-runtime')
    shutil.copyfile(tmp/'101'/'stage'/runtime, stage/runtime)
    assert '__TB371FC_SSH_GATE_READY__' in (stage/runtime).read_text()
    payload = stage/'opt/tb371fc-linux-6.12-r38'
    payload_hashes = {name: digest(payload/name) for name in ('Image', 'board.dtb', 'initramfs.cpio.gz')}
    assert payload_hashes['Image'] == 'dbcffeead9750aa41228269f2101c32c76cbde42d1bea554db1132ad30eac11d'
    load = stage/'bin/load-linux-6.12-r38'
    s = load.read_text()
    assert 'panic=-1' in s
    s = s.replace('panic=-1', 'panic=0 initcall_debug printk.time=1')
    s = s.replace('r118:', 'r120:')
    load.write_text(s)
    execute = stage/'bin/execute-linux-6.12-r38'
    s = execute.read_text()
    anchor = '[ -x "$bb" ] || bb=busybox\n'
    assert s.count(anchor) == 1
    s = s.replace(anchor, anchor + '''
# stdout is the authenticated SSH session; retain trace locally in RAM too.
mark() {
    printf 'R120 HANDOFF: %s\\n' "$*"
    printf 'R120 HANDOFF: %s\\n' "$*" >>/run/tb371fc-r120-handoff.log
}
mark "entered; kernel=$(uname -r); boot_id=$(cat /proc/sys/kernel/random/boot_id)"
[ "$(cat /sys/kernel/kexec_loaded)" = 1 ] || {
    mark 'ABORT: kernel not loaded'; exit 1;
}
''')
    for old, new in (
        ('sync\n', "mark 'sync begin'\nsync\nmark 'sync complete'\n"),
        ('if printf', "mark 'WLAN unbind begin'\n\tif printf"),
        ('\tsleep 1', "\tmark 'WLAN unbind complete'\n\tsleep 1"),
        ('echo 1 >"$wdog"', "mark 'watchdog disable begin'\necho 1 >\"$wdog\"\nmark 'watchdog write complete'"),
        ('"$kexec" -e', "mark 'calling kexec -e'\n\"$kexec\" -e"),
    ):
        assert s.count(old) == 1, old
        s = s.replace(old, new)
    execute.write_text(s)
    for item in (load, execute, stage/runtime, stage/'init'):
        run('sh', '-n', str(item))
    for name, expected in payload_hashes.items():
        assert digest(payload/name) == expected
        assert expected in load.read_text()
    ramdisk = output/'r120.cpio.gz'
    with ramdisk.open('wb') as stream:
        run('bash', '-o', 'pipefail', '-c', 'find . -print0 | sort -z | cpio --null -o --format=newc --owner=0:0 | gzip -9n', cwd=stage, stdout=stream)
    for name in ('kernel', 'dtb', 'recovery_dtbo'):
        shutil.copyfile(base/name, output/name)
    image = output/'tb371fc-r120-recovery.img'
    env = dict(os.environ, RECOVERY_DTBO=str(output/'recovery_dtbo'))
    # Preserve the r118 first-stage command line, independently of 6.12 cmdline.
    info = subprocess.check_output(['python3', unpack, '--boot_img', str(src118), '--out', str(tmp/'info')], text=True)
    cmdlines = [line.split(':', 1)[1].strip() for line in info.splitlines() if line.startswith('command line args:')]
    assert len(cmdlines) == 1
    env['DIAGNOSTIC_CMDLINE'] = cmdlines[0]
    stock = project/'artifacts/device-backup/lun0-recovery_b.bin'
    run('bash', str(project/'scripts/build-diagnostic-recovery.sh'), '/root/mkbootimg/mkbootimg.py', unpack, avb, str(stock), str(output/'kernel'), str(ramdisk), str(output/'dtb'), str(image), env=env)
    with (output/'audit.log').open('w') as report:
        run('bash', str(project/'scripts/verify-diagnostic-recovery.sh'), unpack, avb, str(image), str(stock), str(output/'kernel'), str(ramdisk), str(output/'dtb'), digest(image), env=env, stdout=report, stderr=subprocess.STDOUT)
    shutil.copyfile(load, output/'load-linux-6.12-r38')
    shutil.copyfile(execute, output/'execute-linux-6.12-r38')
    (output/'BUILD-INFO.txt').write_text('R120: r118 payload unchanged; r101 authenticated USB runtime.\n'
        'Second-stage panic=0, initcall_debug, printk.time=1; handoff progress on SSH and RAM.\n'
        'USB/UFS second-stage policy unchanged. Hardware success not yet verified.\n'
        + '\n'.join(f'{name}: {value}' for name, value in payload_hashes.items())+'\n')
    (output/'SHA256SUMS').write_text(''.join(f'{digest(p)}  {p.name}\n' for p in sorted(output.iterdir()) if p.is_file()))
    print('AUDIT_RESULT=PASS', image, digest(image), flush=True)
