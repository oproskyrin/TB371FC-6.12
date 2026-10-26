"""R175: patch the staged R173 initramfs: maintenance stop in /init, persistent root on mmcblk0p2."""
import sys
stage = sys.argv[1]


def patch(path, old, new):
    s = open(path).read()
    assert s.count(old) == 1, (path, old)
    open(path, 'w').write(s.replace(old, new))


# /init: RAM-only maintenance stop (kernel cmdline "tb371fc.maint"), before the microSD is touched
hook = open(__file__.rsplit('/', 1)[0] + '/maint-hook.sh').read()
start = "echo 'TB371FC Arch development loader started.'\n"
patch(stage + '/init', start, hook + start)

# loader: partition 2 (ext4 label tb371fc-root) is the persistent root; the old read-only image +
# RAM overlay path stays as the fallback (no partition 2, or "tb371fc.ramroot" on the cmdline).
loader = stage + '/bin/boot-arch-r129-base'
patch(loader, '"$bb" blockdev --setro /dev/mmcblk0 || rescue \'card read-only ioctl failed\'\n',
      'persistent=\n'
      '# R175: persistent root on microSD partition 2 (ext4, label tb371fc-root)\n'
      'if [ -e /sys/class/block/mmcblk0p2/dev ] && grep -qx \'179:2\' /sys/class/block/mmcblk0p2/dev && ! grep -qw tb371fc.ramroot /proc/cmdline; then\n'
      '    [ -b /dev/mmcblk0p2 ] || "$bb" mknod -m 600 /dev/mmcblk0p2 b 179 2\n'
      '    if "$bb" blkid /dev/mmcblk0p2 | grep -q \'LABEL="tb371fc-root"\'; then\n'
      '        "$bb" blockdev --setro /dev/mmcblk0p1 || true\n'
      '        # SDHC2 IO pads to 1.8 V before any write (BH201 bridge; see tb371fc-bh201.c)\n'
      '        "$bb" insmod /usr/maint/tb371fc-bh201.ko || rescue \'microSD write fix module failed\'\n'
      '        /usr/maint/e2fsck -p /dev/mmcblk0p2 > "$base/e2fsck.txt" 2>&1; rc=$?\n'
      '        echo "R175: root e2fsck rc=$rc"\n'
      '        [ "$rc" -lt 4 ] || rescue "root filesystem check failed rc=$rc (see $base/e2fsck.txt)"\n'
      '        mount -t ext4 -o rw,noatime /dev/mmcblk0p2 /newroot || rescue \'root partition mount failed\'\n'
      '        [ -f /newroot/etc/tb371fc-root-partition ] || rescue \'root partition marker missing\'\n'
      '        [ -x /newroot/usr/lib/systemd/systemd ] || rescue \'systemd missing on the root partition\'\n'
      '        persistent=1; echo \'R175: persistent root on mmcblk0p2\'\n'
      '    fi\n'
      'fi\n'
      'if [ -z "$persistent" ]; then\n'
      '"$bb" blockdev --setro /dev/mmcblk0 || rescue \'card read-only ioctl failed\'\n')
patch(loader, 'mount -t overlay overlay -o "lowerdir=$lowerdirs,upperdir=$base/rw/upper,workdir=$base/rw/work" /newroot || rescue \'overlay root mount failed\'\n',
      'mount -t overlay overlay -o "lowerdir=$lowerdirs,upperdir=$base/rw/upper,workdir=$base/rw/work" /newroot || rescue \'overlay root mount failed\'\n'
      'fi\n')
patch(loader, "echo 'R129: read checks passed; executing Arch systemd with RAM overlay'\n",
      "[ -n \"$persistent\" ] && echo 'R175: executing Arch systemd on the persistent root' || echo 'R129: read checks passed; executing Arch systemd with RAM overlay'\n")
print('R175 patches applied')
# fallback path: the image on partition 1 is now the shrunk 4.19 console image (8 GiB)
patch(loader, '[ "$("$bb" stat -c %s "$image")" = 12884901888 ] || rescue \'unexpected Arch image size\'\n',
      'sz=$("$bb" stat -c %s "$image"); [ $((sz % 1073741824)) -eq 0 ] && [ "$sz" -ge 6442450944 ] || rescue \'unexpected Arch image size\'\n')
print('R175 fallback size check relaxed')
