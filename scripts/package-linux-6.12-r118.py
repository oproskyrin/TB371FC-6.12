#!/usr/bin/env python3
"""Generate r118 from the verified recovery packaging template."""
import hashlib
import pathlib
import subprocess
import tempfile
import re

project = pathlib.Path("$(cd "$(dirname "$0")/.." && pwd)")
pkg = pathlib.Path('/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r118-pinctrl')
base = pathlib.Path('/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r108-headless-microsd-redriver-hog-poll-dtb')
dtb = pkg / 'board.dtb'
assert not dtb.exists()
dtb.write_bytes(next(base.glob('*.dtb')).read_bytes())
def fdt(*args):
    subprocess.run(['fdtput', *args], check=True)
mmc = '/soc/mmc@8804000'
tlmm = '/soc/pinctrl@f100000'
# Restore the existing board pin states using their actual phandles.
def phandle(node):
    return subprocess.check_output(['fdtget','-t','x',str(dtb),node,'phandle'],text=True).strip()
fdt('-t','s',str(dtb),mmc,'pinctrl-names','default','sleep')
fdt('-t','x',str(dtb),mmc,'pinctrl-0',phandle(tlmm+'/sdc2-default-state'))
fdt('-t','x',str(dtb),mmc,'pinctrl-1',phandle(tlmm+'/sdc2-sleep-state'))
# SM8250 RPMH_CXO_CLK is bi_tcxo_div2, not raw 38.4 MHz XO.
# Model the inherited oscillator while RPMh is unavailable after warm kexec.
dts=subprocess.check_output(['dtc','-I','dtb','-O','dts',str(dtb)],text=True,stderr=subprocess.DEVNULL)
new_ph=max(int(x,16) for x in re.findall(r'phandle = <0x([0-9a-f]+)>',dts))+1
xo='/clocks/tb371fc-inherited-cxo-div2'
fdt('-c',str(dtb),xo)
fdt('-t','s',str(dtb),xo,'compatible','fixed-factor-clock')
fdt('-t','x',str(dtb),xo,'#clock-cells','0')
fdt('-t','x',str(dtb),xo,'phandle',f'{new_ph:x}')
fdt('-t','x',str(dtb),xo,'clocks',phandle('/clocks/xo-board'))
fdt('-t','i',str(dtb),xo,'clock-mult','1')
fdt('-t','i',str(dtb),xo,'clock-div','2')
fdt('-t','s',str(dtb),xo,'clock-output-names','tb371fc-inherited-cxo-19m2')
gcc='/soc/clock-controller@100000'
old_clocks=subprocess.check_output(['fdtget','-t','x',str(dtb),gcc,'clocks'],text=True).split()
assert old_clocks == ['2e','0','2e','1','2f']
fdt('-t','x',str(dtb),gcc,'clocks',f'{new_ph:x}',f'{new_ph:x}',old_clocks[-1])
fdt('-t','x',str(dtb),mmc,'clocks','30','89','30','8a',f'{new_ph:x}')
# Keep the high GPIO75 hog: now a built-in provider can actually apply it.
# Avoid a reset pulse until ordinary pinctrl+redriver operation is tested.
base_inner = '/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-arch612-diag39+-safe-diag39-r2/initramfs-6.12-arch-development.cpio.gz'
with tempfile.TemporaryDirectory(prefix='tb371fc-r118-') as tmp:
    stage=pathlib.Path(tmp)
    subprocess.run(['bash','-c','gzip -dc "$1" | cpio -idmu', 'unpack',base_inner],cwd=stage,check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    loader=stage/'bin/boot-arch-development-rootfs'
    s=loader.read_text()
    old="\techo 'USB NCM rescue shell remains on 169.254.77.2:2323.' >&2"
    assert s.count(old)==1
    s=s.replace(old,"""\tmkdir -p /run/r118
\tdmesg > /run/r118/dmesg.txt
\tcat /sys/kernel/debug/devices_deferred > /run/r118/deferred.txt 2>/dev/null || true
\tcat /sys/kernel/debug/gpio > /run/r118/gpio.txt 2>/dev/null || true
\tcat /sys/kernel/debug/clk/clk_summary > /run/r118/clocks.txt 2>/dev/null || true
\techo 'R118: built-in SM8250 pinctrl; GPIO75 hog; native SD pad states' >&2
\tuname -r >&2
\tcat /run/r118/deferred.txt >&2
\tdmesg | grep -iE 'pinctrl|gpio|mmc|sdhci' | busybox tail -n 55 >&2
\techo 'Logs: /run/r118 (RAM only); USB disabled in this candidate.' >&2""")
    marker='mkdir -p "$new_root/run"'
    assert marker in s
    s=s[:s.index(marker)]+'''# Boot regular headless Arch after verifying its image marker.
dmesg > "$new_root/var/log/tb371fc-r118-kernel.log"
cat /proc/cmdline > "$new_root/var/log/tb371fc-r118-cmdline.log"
[ -x "$new_root/sbin/init" ] || rescue 'Arch /sbin/init missing'
mkdir -p "$new_root/run" "$new_root/dev" "$new_root/proc" "$new_root/sys"
umount -l "$sd_mount" || rescue 'cannot detach SD mount'
for fs in run dev proc sys; do
    mount --move "/$fs" "$new_root/$fs" || rescue "cannot move $fs"
done
sync
exec switch_root "$new_root" /sbin/init
'''
    loader.write_text(s)
    subprocess.run(['sh','-n',str(loader)],check=True)
    inner=pkg/'initramfs.cpio.gz'
    with inner.open('wb') as out:
        subprocess.run(['bash','-c','find . -print0 | sort -z | cpio --null -o --format=newc --owner=0:0 2>/dev/null | gzip -9n'],cwd=stage,stdout=out,check=True)

sha=hashlib.sha256(inner.read_bytes()).hexdigest()
s=(project/'scripts/build-v56-6-controlled-linux-6.12-r64-transport-r2.sh').read_text()
s=s.replace('r64','r118')
lines=s.splitlines()
for i,line in enumerate(lines):
    if line.startswith('linux612='): lines[i]=f'linux612={pkg}/Image'
    if line.startswith('linux612_dtb='): lines[i]=f'linux612_dtb={dtb}'
    if line.startswith('linux612_initrd='): lines[i]=f'linux612_initrd={inner}'
s='\n'.join(lines)+'\n'
s=s.replace('c807299d26b83c2d585a1ae8402dfbb68852a647ed153bf190123e9a7048dd9c',sha)
# The loader template itself contains the old initramfs hash.
anchor='chmod 0755 "$stage/bin/load-linux-6.12-r38"\n'
s=s.replace(anchor,anchor+f'''sed -i 's/c807299d26b83c2d585a1ae8402dfbb68852a647ed153bf190123e9a7048dd9c/{sha}/g; s/fw_devlink=permissive/fw_devlink=off/; s/reset_devices/reset_devices rodata=on systemd.unit=multi-user.target/' "$stage/bin/load-linux-6.12-r38"
grep -Fq '{sha}' "$stage/bin/load-linux-6.12-r38"
''')
s='\n'.join(line for line in s.splitlines() if not ('grep -Fq' in line and ('TB371FC_SERIAL_SSH_SESSION_TIMEOUT' in line or '__TB371FC_SSH_STREAM_CLOSED__' in line)))+'\n'
s=s.replace('Linux 6.12 payload: r118 embedded early page-table pool candidate fix plus\npost-paging_init PSCI reset checkpoint; r57 DTB and proven Arch initramfs.',
'''Linux 6.12 payload: rebuilt r68 source with diagnostic SMC replaced by NOP,
built-in PINCTRL_MSM and PINCTRL_SM8250. r108 DT with native MMC pin states.
GCC/MMC inherited CXO modeled as 38.4 MHz / 2, matching SM8250 RPMh driver.
GPIO75 hog retained. PIO and USB/UFS disabled. Regular Arch multi-user target.
Hardware boot not yet verified. This is a candidate, not a proven release.''')
generated=pkg/'package-recovery.sh'
generated.write_text(s)
subprocess.run(['bash',str(generated)],check=True)
