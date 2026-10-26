#!/bin/sh
export PATH=/sbin:/bin:/usr/sbin:/usr/bin
bb=/bin/busybox
base=/run/r129
mkdir -p "$base" "$base/sd" "$base/lower" "$base/rw" /newroot
echo 'R129: Arch headless boot; SD read-only, writable root in RAM'
uname -r
rescue() {
    dmesg > "$base/dmesg.txt"
    cat /proc/mounts > "$base/mounts.txt"
    echo "R129 STOP: $*"
    echo 'R129 logs in /run/r129; no automatic reboot'
    exec setsid cttyhack sh
}
mount --make-rprivate / || rescue 'cannot make mounts private'
for n in $(seq 1 40); do
    [ -e /sys/class/block/mmcblk0p1/dev ] && break
    sleep 1
done
[ -e /sys/class/block/mmcblk0p1/dev ] || rescue 'microSD partition absent'
grep -qx '179:0' /sys/class/block/mmcblk0/dev || rescue 'unexpected card device'
grep -qx '179:1' /sys/class/block/mmcblk0p1/dev || rescue 'unexpected partition device'
[ -b /dev/mmcblk0 ] || "$bb" mknod -m 600 /dev/mmcblk0 b 179 0
[ -b /dev/mmcblk0p1 ] || "$bb" mknod -m 600 /dev/mmcblk0p1 b 179 1
"$bb" blockdev --setro /dev/mmcblk0 || rescue 'card read-only ioctl failed'
"$bb" blockdev --setro /dev/mmcblk0p1 || rescue 'partition read-only ioctl failed'
for offset in 0 8192 32768; do
    reference=
    for round in 1 2 3; do
        "$bb" timeout 12 "$bb" dd if=/dev/mmcblk0 of="$base/sample.bin" iflag=direct bs=4096 skip="$offset" count=256 2>"$base/direct-$offset-$round.txt" || rescue "direct SD read failed: $offset/$round"
        [ "$("$bb" stat -c %s "$base/sample.bin")" = 1048576 ] || rescue 'short direct read'
        sum=$("$bb" sha256sum "$base/sample.bin" | "$bb" awk '{print $1}')
        [ -n "$reference" ] || reference=$sum
        [ "$sum" = "$reference" ] || rescue 'direct read checksum changed'
        echo "R129 DIRECT READ offset=$offset round=$round OK"
    done
done
mount -t exfat -o ro,noatime /dev/mmcblk0p1 "$base/sd" || rescue 'read-only exFAT mount failed'
image=$base/sd/tb371fc-linux/tb371fc-arch-development.raw
[ -f "$image" ] || rescue 'Arch image missing'
[ "$("$bb" stat -c %s "$image")" = 12884901888 ] || rescue 'unexpected Arch image size'
[ -b /dev/loop0 ] || "$bb" mknod -m 600 /dev/loop0 b 7 0
"$bb" losetup -r /dev/loop0 "$image" || rescue 'read-only loop setup failed'
mount -t ext4 -o ro,noload /dev/loop0 "$base/lower" || rescue 'read-only ext4 mount failed'
[ -f "$base/lower/etc/tb371fc-development-image" ] || rescue 'Arch marker missing'
[ -x "$base/lower/usr/lib/systemd/systemd" ] || rescue 'systemd missing'
mount -t tmpfs -o size=512M,mode=0755 tmpfs "$base/rw" || rescue 'RAM upper mount failed'
mkdir -p "$base/rw/upper" "$base/rw/work"
mount -t overlay overlay -o "lowerdir=$base/lower,upperdir=$base/rw/upper,workdir=$base/rw/work" /newroot || rescue 'overlay root mount failed'
mkdir -p /newroot/etc/systemd/system/timers.target.wants /newroot/etc/systemd/journald.conf.d /newroot/usr/local/sbin
cp /r129-config/fstab /newroot/etc/fstab || rescue 'volatile fstab install failed'
cp /r129-config/r129-evidence.service /r129-config/r129-evidence.timer /newroot/etc/systemd/system/ || rescue 'evidence units install failed'
cp /r129-config/r129-evidence.sh /newroot/usr/local/sbin/tb371fc-r129-evidence || rescue 'evidence script install failed'
chmod 0755 /newroot/usr/local/sbin/tb371fc-r129-evidence
cp /r129-config/journald.conf /newroot/etc/systemd/journald.conf.d/r129.conf || rescue 'volatile journal config failed'
ln -sf ../r129-evidence.timer /newroot/etc/systemd/system/timers.target.wants/r129-evidence.timer || rescue 'evidence timer enable failed'
for unit in display-manager.service systemd-fsck-root.service systemd-remount-fs.service; do
    ln -sf /dev/null "/newroot/etc/systemd/system/$unit" || rescue 'volatile unit mask failed'
done
mkdir -p /newroot/run /newroot/dev /newroot/proc /newroot/sys
cat /proc/mounts > "$base/pre-handoff-mounts.txt"
dmesg > "$base/pre-handoff-dmesg.txt"
echo 'R129: read checks passed; executing Arch systemd with RAM overlay'
dmesg -n 4
for fs in dev proc sys; do
    mount --move "/$fs" "/newroot/$fs" || rescue "cannot move $fs"
done
mount --move /run /newroot/run || {
    echo 'R129: cannot move /run; entering shell'
    exec setsid cttyhack sh
}
exec switch_root /newroot /sbin/init
