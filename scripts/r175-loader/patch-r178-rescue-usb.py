"""R178: loader rescue() brings up the USB link and a shell on 172.31.77.2:2323, so a failed boot
(no card, no root) can be inspected remotely instead of needing a photo of the screen."""
import sys
stage = sys.argv[1]
p = stage + '/bin/boot-arch-r129-base'
s = open(p).read()
old = "    echo 'R129 logs in /run/r129; no automatic reboot'\n"
assert s.count(old) == 1
new = old + ("    mkdir -p /run/maint-bin; /bin/busybox --install -s /run/maint-bin\n"
             "    PATH=/run/maint-bin:$PATH /run/r130/busybox sh /run/r130/config/start-usb.sh > /run/r129/rescue-usb.log 2>&1 || true\n"
             "    ( exec /bin/busybox nc -lk -p 2323 -e /bin/sh ) &\n"
             "    echo 'R178: rescue shell on USB 172.31.77.2:2323'\n")
s = s.replace(old, new)
open(p, 'w').write(s)
print('R178 rescue USB patch applied')

# R178: switch the microSD to a UHS-I mode (default SDR50, 100 MHz) after the card is up in High
# Speed and before the root is mounted (enabling UHS at host probe hangs the boot). The card is
# still in 1.8 V signalling from the vendor kernel, so the core's v18 fixup path is used.
old = '        /usr/maint/e2fsck -p /dev/mmcblk0p2 > "$base/e2fsck.txt" 2>&1; rc=$?\n'
assert s.count(old) == 1
new = ('        if ! grep -qw tb371fc.nouhs /proc/cmdline; then\n'
       '            "$bb" insmod /usr/maint/tb371fc-uhs.ko $(grep -o "tb371fc.uhs=[^ ]*" /proc/cmdline | sed "s/tb371fc.uhs=/modes=/") || echo "R178: UHS module failed"\n'
       '            for n in $(seq 1 10); do [ -b /dev/mmcblk0p2 ] && [ -e /sys/class/block/mmcblk0p2 ] && break; sleep 1; done\n'
       '            grep -E "^(clock|timing)" /sys/kernel/debug/mmc0/ios | tr "\n" " "; echo\n'
       '        fi\n') + old
s = s.replace(old, new)
open(p, 'w').write(s)
print('R178 UHS switch patch applied')
