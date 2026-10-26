#!/usr/bin/env python3
"""R169: R121 recovery + optional autoboot of the Linux 6.12 R169 desktop (touch, KDE, keyboard, sleep masked, speakers, Wi-Fi, apps layer).

Only the ramdisk changes:
  - boot-arch-development-rootfs copies tb371fc-linux/autoboot-6.12/{Image,
    board.dtb,initramfs.cpio.gz} from microSD into /run when ENABLE exists,
    and preserves the autoboot helper;
  - the development init starts /run/tb371fc-rescue/tb371fc-autoboot-612
    once the console (SSH, rescue shell) is ready;
  - new bin/tb371fc-autoboot-612 (hash-pinned payload, 7 s cancel window).
Kernel, DTB, recovery_dtbo and command line are R121's, byte for byte.
"""
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

project = Path(__file__).resolve().parent.parent
builds = Path('/mnt/d/TB371FC-builds')
source = builds/'linux-6.12.30-tb371fc-r121-panic-gate-20261023/tb371fc-r121-recovery.img'
output = builds/'linux-6.12.30-tb371fc-r169-autoboot-20261025'
unpack = '/root/mkbootimg/unpack_bootimg.py'
avb = '/root/avb/avbtool.py'
stock = project/'artifacts/device-backup/lun0-recovery_b.bin'
helper = project/'scripts/r169-recovery/tb371fc-autoboot-612'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(*args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)


def replace_once(text, old, new):
    assert text.count(old) == 1, old
    return text.replace(old, new, 1)


assert digest(source) == '976b4820c956f011da6b21ef20884c9d344914afcfb1b7836021ca5c69f047e6'
output.mkdir(exist_ok=False)
with tempfile.TemporaryDirectory(prefix='tb371fc-r169-') as temp:
    tmp = Path(temp)
    info = subprocess.check_output(['python3', unpack, '--boot_img', str(source), '--out', str(tmp)], text=True)
    stage = tmp/'stage'
    stage.mkdir()
    run('bash', '-o', 'pipefail', '-c', 'gzip -dc "$1" | cpio -idmu', 'unpack', str(tmp/'ramdisk'), cwd=stage, stderr=subprocess.DEVNULL)

    rootfs = stage/'bin/boot-arch-development-rootfs'
    text = rootfs.read_text()
    text = replace_once(text, '[ -f "$image" ] || rescue "development image is missing: $image_name"\n',
        '[ -f "$image" ] || rescue "development image is missing: $image_name"\n'
        '# R150 autoboot: stage the hash-pinned Linux 6.12 payload in RAM (read only).\n'
        'autoboot_dir="$sd_mount/tb371fc-linux/autoboot-6.12-r169"\n'
        'if [ -f "$autoboot_dir/ENABLE" ]; then\n'
        '\tmkdir -p /run/tb371fc-autoboot\n'
        '\tfor f in Image board.dtb initramfs.cpio.gz; do\n'
        '\t\tcp "$autoboot_dir/$f" "/run/tb371fc-autoboot/$f" || { rm -rf /run/tb371fc-autoboot; break; }\n'
        '\tdone\n'
        'fi\n')
    text = replace_once(text, 'for helper in collect-hardware-snapshot capture-input-events input-monitor; do\n\t[ -x "/bin/$helper" ] || continue',
        'for helper in collect-hardware-snapshot capture-input-events input-monitor tb371fc-autoboot-612; do\n\t[ -x "/bin/$helper" ] || continue')
    text = replace_once(text, 'for helper in collect-hardware-snapshot capture-input-events input-monitor; do\n\t[ ! -e',
        'for helper in collect-hardware-snapshot capture-input-events input-monitor tb371fc-autoboot-612; do\n\t[ ! -e')
    rootfs.write_text(text)

    init = stage/'bin/tb371fc-development-init-runtime'
    text = init.read_text()
    text = replace_once(text, '\nwhile :; do\n\tsleep 5\n',
        '\n# R150: optional autoboot into Linux 6.12 (cancel window on screen).\n'
        'if [ -x /run/tb371fc-rescue/tb371fc-autoboot-612 ] && [ -d /run/tb371fc-autoboot ]; then\n'
        '\t"$bb" setsid "$bb" sh /run/tb371fc-rescue/tb371fc-autoboot-612 \\\n'
        '\t\t>/run/tb371fc-autoboot.log 2>&1 &\n'
        'fi\n'
        '\nwhile :; do\n\tsleep 5\n')
    init.write_text(text)

    target = stage/'bin/tb371fc-autoboot-612'
    target.write_bytes(helper.read_bytes().replace(b'\r\n', b'\n'))
    target.chmod(0o755)
    for path in (rootfs, init, target):
        run('sh', '-n', str(path))

    ramdisk = output/'r169.cpio.gz'
    with ramdisk.open('wb') as stream:
        run('bash', '-o', 'pipefail', '-c', 'find . -print0 | sort -z | cpio --null -o --format=newc --owner=0:0 | gzip -9n', cwd=stage, stdout=stream, stderr=subprocess.DEVNULL)
    for name in ('kernel', 'dtb', 'recovery_dtbo'):
        shutil.copyfile(tmp/name, output/name)
    cmdlines = [line.split(':', 1)[1].strip() for line in info.splitlines() if line.startswith('command line args:')]
    assert len(cmdlines) == 1 and 'panic=0' in cmdlines[0]
    env = dict(os.environ, RECOVERY_DTBO=str(output/'recovery_dtbo'), DIAGNOSTIC_CMDLINE=cmdlines[0])
    image = output/'tb371fc-r169-recovery.img'
    run('bash', str(project/'scripts/build-diagnostic-recovery.sh'), '/root/mkbootimg/mkbootimg.py', unpack, avb, str(stock), str(output/'kernel'), str(ramdisk), str(output/'dtb'), str(image), env=env)
    with (output/'audit.log').open('w') as report:
        run('bash', str(project/'scripts/verify-diagnostic-recovery.sh'), unpack, avb, str(image), str(stock), str(output/'kernel'), str(ramdisk), str(output/'dtb'), digest(image), env=env, stdout=report, stderr=subprocess.STDOUT)
    for name in ('kernel', 'dtb', 'recovery_dtbo'):
        assert digest(output/name) == digest(builds/'linux-6.12.30-tb371fc-r121-panic-gate-20261023'/name), name
    shutil.copyfile(rootfs, output/'boot-arch-development-rootfs')
    shutil.copyfile(init, output/'tb371fc-development-init-runtime')
    shutil.copyfile(target, output/'tb371fc-autoboot-612')
    (output/'BUILD-INFO.txt').write_text('R169: R121 recovery (kernel/DTB/dtbo/cmdline identical) + microSD autoboot (tb371fc-linux/autoboot-6.12-r169) of the hash-pinned Linux 6.12 R169 payload (touch, KDE, keyboard, sleep masked, speakers, Wi-Fi, apps layer) with a 7 s cancel window.\n')
    (output/'SHA256SUMS').write_text(''.join(f'{digest(p)}  {p.name}\n' for p in sorted(output.iterdir()) if p.is_file()))
    print('AUDIT_RESULT=PASS', image, digest(image), flush=True)
