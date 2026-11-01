"""Mechanical R201 ramdisk update: select verified R226, retain R201 fallback."""
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

p = Path('/mnt/c/Users/Sailren/Documents/ChatGPT/linux lenovo')
b = Path('/mnt/d/TB371FC-builds')
base = b/'linux-6.12.114-tb371fc-r201-autoboot-20261026'
dest = b/'r226-v3-selectionfix-recovery'
source = base/'tb371fc-r201-recovery.img'
stock = p/'artifacts/device-backup-HA1W9R9R-20260810/lun0-recovery_b.bin'
unpack = '/root/mkbootimg/unpack_bootimg.py'
avb = '/root/avb/avbtool.py'
old = ('92e8a30f3195660ad95f044e1d2ea2070c1acd37bfe456f67d90c203f10bb26b',
       '04a223660b5c281c181d2180329db0ba62654ed6441d121ded8a7d38b1106a8a',
       '7aae7512d97d6b1ed4acea64360e9fc5e0b55cac7553d5d9ca0c24642546ec2d')
new = ('7a59c7b2931c8e8925446a3cec5432a0912d5f0e3f9365058de2492ad6d0d157',
       'd061e7e3445936db745308098a625fe060a69d6874840ded62cb110b5f18f775',
       '0bcad91fa94af6ee794b85c52da12180709c729690a992864090981dc75f1219')
names = ('Image', 'board.dtb', 'initramfs.cpio.gz')
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def run(*args, **kw): return subprocess.run(args, check=True, **kw)
assert sha(source) == '800307febff4f2e8387e1a73d9759e03375db1333c6e67537062ea22f0093f68'
assert not (dest/'tb371fc-r226-recovery.img').exists(), 'refusing to overwrite a recovery build'
dest.mkdir(exist_ok=True)
with tempfile.TemporaryDirectory(prefix='tb371fc-r226-recovery-') as tmpname:
    tmp = Path(tmpname)
    info = subprocess.check_output(['python3', unpack, '--boot_img', str(source), '--out', str(tmp)], text=True)
    stage = tmp/'stage'; stage.mkdir()
    run('bash', '-o', 'pipefail', '-c', 'gzip -dc "$1" | cpio -idmu', 'unpack', str(tmp/'ramdisk'), cwd=stage, stderr=subprocess.DEVNULL)
    root = stage/'bin/boot-arch-development-rootfs'
    text = root.read_text()
    anchor = 'autoboot_dir="$sd_mount/tb371fc-linux/autoboot-6.12-r201"\n'
    assert text.count(anchor) == 1
    hook = 'r226_bb=/bin/busybox\ncandidate="$sd_mount/tb371fc-linux/autoboot-6.12-r226"\n'
    hook += 'r226_valid=1\n[ -f "$candidate/ENABLE" ] || r226_valid=0\n'
    for name, digest in zip(names, new):
        hook += f'[ "$("$r226_bb" sha256sum "$candidate/{name}" 2>/dev/null | "$r226_bb" awk \'{{print $1}}\')" = {digest} ] || r226_valid=0\n'
    hook += '[ "$r226_valid" = 1 ] && autoboot_dir="$candidate"\n'
    root.write_text(text.replace(anchor, anchor+hook))
    # Exercise the GENERATED selector with real v2 files, without inherited bb.
    test_sd = tmp/'selector-test'; test_candidate = test_sd/'tb371fc-linux/autoboot-6.12-r226'
    test_candidate.mkdir(parents=True)
    payload = b/'r226-v2-timerfix'
    for name, filename in zip(names, ('Image','board-usb3.dtb','initramfs.cpio.gz')):
        (test_candidate/name).symlink_to(payload/filename)
    (test_candidate/'ENABLE').touch()
    selector = anchor+hook+'printf "%s" "$autoboot_dir"\n'
    assert (stage/'bin/busybox').is_file(), 'production initrd BusyBox missing'
    # WSL host has no native BusyBox. Adapter dispatches the same sha256sum/awk
    # argv to host coreutils; production /bin/busybox is checked above.
    adapter = tmp/'host-busybox-adapter'
    adapter.write_text('#!/bin/sh\nexec "$@"\n'); adapter.chmod(0o755)
    host_selector = selector.replace('r226_bb=/bin/busybox', f'r226_bb="{adapter}"')
    def selection():
        return subprocess.check_output(['sh','-u','-c','sd_mount="$1"\n'+host_selector,'test',str(test_sd)], env={k:v for k,v in os.environ.items() if k != 'bb'}, text=True)
    assert selection() == str(test_candidate), 'R226 selection failed'
    (test_candidate/'ENABLE').unlink()
    assert selection() == str(test_sd/'tb371fc-linux/autoboot-6.12-r201'), 'R201 fallback failed'
    (test_candidate/'ENABLE').touch()
    (test_candidate/'Image').unlink()
    (test_candidate/'Image').write_bytes(b'invalid candidate')
    assert selection() == str(test_sd/'tb371fc-linux/autoboot-6.12-r201'), 'bad-hash fallback failed'
    print('Generated selector tests PASS: valid R226, missing ENABLE -> R201, bad SHA -> R201')
    helper = stage/'bin/tb371fc-autoboot-612'
    text = helper.read_text()
    start = text.index('hash_ok Image ')
    end = text.index('[ -x "$kexec" ]', start)
    guards = f'if hash_ok Image {new[0]}; then\n'
    for name, digest in zip(names[1:], new[1:]):
        guards += f" hash_ok {name} {digest} || fail 'R226 {name} hash mismatch'\n"
    guards += " extra_flags='tb371fc.sd150 tb371fc.r226 tb371fc.usb3test'\n"
    guards += f'elif hash_ok Image {old[0]}; then\n'
    for name, digest in zip(names[1:], old[1:]):
        guards += f" hash_ok {name} {digest} || fail 'R201 {name} hash mismatch'\n"
    guards += " extra_flags=''\nelse\n fail 'neither R226 nor R201 Image hash matches'\nfi\n"
    text = text[:start]+guards+text[end:]
    assert text.count('--append="$cmdline"') == 1
    helper.write_text(text.replace('--append="$cmdline"', '--append="$cmdline $extra_flags"'))
    for path in (root, helper): run('sh', '-n', str(path))
    ramdisk = dest/'r226.cpio.gz'
    with ramdisk.open('wb') as stream:
        run('bash', '-o', 'pipefail', '-c', 'find . -print0 | sort -z | cpio --null -o --format=newc --owner=0:0 | gzip -9n', cwd=stage, stdout=stream, stderr=subprocess.DEVNULL)
    for name in ('kernel', 'dtb', 'recovery_dtbo'):
        shutil.copyfile(tmp/name, dest/name)
        assert sha(dest/name) == sha(base/name), name
    cmdline = [s.split(':',1)[1].strip() for s in info.splitlines() if s.startswith('command line args:')]
    assert len(cmdline) == 1
    env = dict(os.environ, RECOVERY_DTBO=str(dest/'recovery_dtbo'), DIAGNOSTIC_CMDLINE=cmdline[0])
    image = dest/'tb371fc-r226-recovery.img'
    run('bash', str(p/'scripts/build-diagnostic-recovery.sh'), '/root/mkbootimg/mkbootimg.py', unpack, avb, str(stock), str(dest/'kernel'), str(ramdisk), str(dest/'dtb'), str(image), env=env)
    with (dest/'audit.log').open('w') as report:
        run('bash', str(p/'scripts/verify-diagnostic-recovery.sh'), unpack, avb, str(image), str(stock), str(dest/'kernel'), str(ramdisk), str(dest/'dtb'), sha(image), env=env, stdout=report, stderr=subprocess.STDOUT)
    shutil.copyfile(root, dest/root.name)
    shutil.copyfile(helper, dest/helper.name)
    (dest/'SHA256SUMS').write_text(''.join(f'{sha(f)}  {f.name}\n' for f in sorted(dest.iterdir()) if f.is_file()))
    print('R226 recovery AUDIT PASS:', sha(image), 'kernel/DT/dtbo unchanged; not flashed')
