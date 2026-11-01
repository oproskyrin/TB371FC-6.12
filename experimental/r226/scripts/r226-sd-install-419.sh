#!/bin/sh
set -eu
bb=/run/tb371fc-rescue/busybox
test "$(uname -r)" = 4.19.157-perf-v56.6+
test "$(cat /sys/class/block/mmcblk0/device/cid)" = 1b534d45443253353044f46849a18800
grep -qx 'PARTNAME=recovery_b' /sys/class/block/sda8/uevent
recovery=/dev/sda8
test -b "$recovery"
test "$("$bb" blockdev --getsize64 "$recovery")" = 104857600
recovery_sha=$("$bb" sha256sum "$recovery" | "$bb" awk '{print $1}')
echo "Current recovery_b SHA256=$recovery_sha"
test "$recovery_sha" = 800307febff4f2e8387e1a73d9759e03375db1333c6e67537062ea22f0093f68
echo 'Current recovery_b matches preserved R201 rollback image'
src=/run/r226-install
mnt=/mnt/r226-install
mkdir -p "$src" "$mnt"
"$bb" tar -xzf /run/r226-combined-payload.tar.gz -C "$src"
check() { test "$("$bb" sha256sum "$1" | "$bb" awk '{print $1}')" = "$2"; }
check "$src/Image" 7a59c7b2931c8e8925446a3cec5432a0912d5f0e3f9365058de2492ad6d0d157
check "$src/board-usb3.dtb" d061e7e3445936db745308098a625fe060a69d6874840ded62cb110b5f18f775
check "$src/initramfs.cpio.gz" 0bcad91fa94af6ee794b85c52da12180709c729690a992864090981dc75f1219
mount -t exfat -o rw,noatime /dev/mmcblk0p1 "$mnt"
trap 'umount "$mnt"' EXIT
old="$mnt/tb371fc-linux/autoboot-6.12-r201"
check "$old/Image" 92e8a30f3195660ad95f044e1d2ea2070c1acd37bfe456f67d90c203f10bb26b
check "$old/board.dtb" 04a223660b5c281c181d2180329db0ba62654ed6441d121ded8a7d38b1106a8a
check "$old/initramfs.cpio.gz" 7aae7512d97d6b1ed4acea64360e9fc5e0b55cac7553d5d9ca0c24642546ec2d
test -f "$old/ENABLE"
dest="$mnt/tb371fc-linux/autoboot-6.12-r226"
test ! -e "$dest"
mkdir "$dest"
cp "$src/Image" "$dest/Image.partial"
cp "$src/board-usb3.dtb" "$dest/board.dtb.partial"
cp "$src/initramfs.cpio.gz" "$dest/initramfs.cpio.gz.partial"
for name in Image board.dtb initramfs.cpio.gz; do mv "$dest/$name.partial" "$dest/$name"; done
sync
echo 3 > /proc/sys/vm/drop_caches
check "$dest/Image" 7a59c7b2931c8e8925446a3cec5432a0912d5f0e3f9365058de2492ad6d0d157
check "$dest/board.dtb" d061e7e3445936db745308098a625fe060a69d6874840ded62cb110b5f18f775
check "$dest/initramfs.cpio.gz" 0bcad91fa94af6ee794b85c52da12180709c729690a992864090981dc75f1219
(cd "$dest"; "$bb" sha256sum Image board.dtb initramfs.cpio.gz) > "$dest/SHA256SUMS"
printf '%s\n' 'R226 v2 SD150 + fixed-orientation USB3; remove ENABLE to use preserved R201' > "$dest/ENABLE"
sync
umount "$mnt"
trap - EXIT
echo 'R226_SD_INSTALL_OK: versioned new folder verified; R201 untouched'
