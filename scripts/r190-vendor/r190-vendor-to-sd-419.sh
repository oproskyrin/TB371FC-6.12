#!/bin/sh
# R190 (4.19 console): copy the vendor_a logical partition (3 extents of super /dev/sda6, offsets from
# lp-parse.py, 512-byte sectors) into one image on microSD p1. UFS is only read.
set -eu
bb=/run/tb371fc-rescue/busybox; src=/dev/sda6; mnt=/mnt/r190-sd
[ -b $src ] || "$bb" mknod $src b $(cat /sys/class/block/sda6/dev | "$bb" tr ':' ' ')
mkdir -p $mnt; mountpoint -q $mnt || mount -t exfat -o rw,noatime /dev/mmcblk0p1 $mnt
out=$mnt/tb371fc-linux/vendor-a-r190.img; rm -f $out.partial
# extents in 4 KiB blocks: sector/8
"$bb" dd if=$src of=$out.partial bs=4096 skip=1779200 count=196096 2>&1 | "$bb" tail -1
"$bb" dd if=$src of=$out.partial bs=4096 skip=640 count=128 seek=196096 conv=notrunc 2>&1 | "$bb" tail -1
"$bb" dd if=$src of=$out.partial bs=4096 skip=1662336 count=150 seek=196224 conv=notrunc 2>&1 | "$bb" tail -1
sync; mv $out.partial $out; ls -la $out
"$bb" dd if=$out bs=1 skip=1080 count=2 2>/dev/null | "$bb" od -A n -t x1   # ext4 magic 53 ef
"$bb" sha256sum $out
sync; umount $mnt; echo R190_VENDOR_DONE
