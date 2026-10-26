#!/bin/sh
# Replaces the automatic RW Arch handoff inside the diagnostic initramfs.
export PATH=/sbin:/bin:/usr/sbin:/usr/bin
bb=/bin/busybox
mkdir -p /run/r128 /mnt/sd /newroot
echo 'R128: GPIO75 redriver test; microSD READ ONLY; no automatic Arch boot'
uname -r
finish() {
    dmesg > /run/r128/dmesg.txt
    cat /proc/partitions > /run/r128/partitions.txt
    cat /proc/mounts > /run/r128/mounts.txt
    cat /sys/kernel/debug/devices_deferred > /run/r128/deferred.txt 2>/dev/null || true
    echo "R128 RESULT: $*"
    echo 'R128 logs: /run/r128 (RAM only). USB unavailable.'
    dmesg | grep -iE 'mmc|sdhci|redriver|hogged' | "$bb" tail -n 20
    exec setsid cttyhack sh
}
for n in $(seq 1 40); do
    [ -e /sys/class/block/mmcblk0p1/dev ] && break
    sleep 1
done
[ -e /sys/class/block/mmcblk0p1/dev ] || finish 'partition absent'
grep -qx '179:0' /sys/class/block/mmcblk0/dev || finish 'unexpected card device'
grep -qx '179:1' /sys/class/block/mmcblk0p1/dev || finish 'unexpected partition device'
[ -b /dev/mmcblk0 ] || "$bb" mknod -m 600 /dev/mmcblk0 b 179 0
[ -b /dev/mmcblk0p1 ] || "$bb" mknod -m 600 /dev/mmcblk0p1 b 179 1
"$bb" blockdev --setro /dev/mmcblk0 2>/dev/null || true
"$bb" blockdev --setro /dev/mmcblk0p1 2>/dev/null || true
reference=
for n in $(seq 1 8); do
    "$bb" timeout 12 "$bb" dd if=/dev/mmcblk0 of=/run/r128/sample.bin bs=4096 count=256 2>/run/r128/read-$n.txt || finish "raw read failed, round $n"
    [ "$("$bb" stat -c %s /run/r128/sample.bin)" = 1048576 ] || finish "short read, round $n"
    sum=$("$bb" sha256sum /run/r128/sample.bin | "$bb" awk '{print $1}')
    [ -n "$reference" ] || reference=$sum
    [ "$sum" = "$reference" ] || finish "read checksum changed, round $n"
    echo "R128 SD READ $n/8 OK $sum"
    sleep 2
done
mount -t exfat -o ro,noatime /dev/mmcblk0p1 /mnt/sd || finish 'read-only exFAT mount failed'
image=/mnt/sd/tb371fc-linux/tb371fc-arch-development.raw
[ -f "$image" ] || finish 'Arch image missing'
echo "R128 Arch image bytes: $("$bb" stat -c %s "$image")"
[ -b /dev/loop0 ] || "$bb" mknod -m 600 /dev/loop0 b 7 0
"$bb" losetup -r /dev/loop0 "$image" || finish 'read-only loop setup failed'
mount -t ext4 -o ro,noload /dev/loop0 /newroot || finish 'read-only ext4 mount failed'
[ -f /newroot/etc/tb371fc-development-image ] || finish 'Arch marker missing'
cat /newroot/etc/tb371fc-development-image
finish '8 raw reads matched; exFAT and Arch ext4 readable read-only'
