#!/usr/bin/env bash
# R174: build the two microSD images from the backup (D:/TB371FC-builds/sd-backup-20261025):
#  root.img     ext4 "tb371fc-root" = base image + r163-apps + r171-apps merged (for partition 2,
#               grown to the full partition on the tablet with resize2fs)
#  console.raw  the base image shrunk to 8 GiB (the 4.19 console boots from it, partition 1 exFAT)
set -euo pipefail
b=/mnt/d/TB371FC-builds/sd-backup-20261025; w=/root/tb371fc/sdmig; mkdir -p "$w"
cd "$w"
[ -f base.raw ] || zstd -dq "$b/arch-development.raw.zst" -o base.raw
e2fsck -fn base.raw | tail -2
mkdir -p small; tar -xf "$b/small.tar" -C small
for m in base r163 r171 merged root; do mkdir -p mnt-$m; mountpoint -q mnt-$m && umount mnt-$m; done
mount -o ro,loop,noload base.raw mnt-base
mount -o ro,loop,noload small/layers/r163-apps.img mnt-r163
mount -o ro,loop,noload small/layers/r171-apps.img mnt-r171
mkdir -p ovl-upper ovl-work; rm -rf ovl-upper/* ovl-work/*
mount -t overlay overlay -o ro,lowerdir=mnt-r171:mnt-r163:mnt-base mnt-merged
du -sh --apparent-size mnt-merged 2>/dev/null | tail -1
rm -f root.img; truncate -s 10G root.img
mkfs.ext4 -q -F -L tb371fc-root -m 1 root.img
mount -o loop root.img mnt-root
rsync -aHAX --numeric-ids mnt-merged/ mnt-root/
touch mnt-root/etc/tb371fc-root-partition
ls mnt-root/etc/tb371fc-*
df -h mnt-root | tail -1
umount mnt-root mnt-merged mnt-r171 mnt-r163 mnt-base
e2fsck -fy root.img | tail -1
# console image: same base, shrunk to 8 GiB
cp --sparse=always base.raw console.raw
e2fsck -fy console.raw | tail -1
resize2fs console.raw 8G | tail -1
truncate -s 8G console.raw
e2fsck -fn console.raw | tail -1
ls -las root.img console.raw
zstd -q -T0 -1 -f root.img -o "$b/root.img.zst"; zstd -q -T0 -1 -f console.raw -o "$b/console.raw.zst"
sha256sum root.img console.raw | tee "$b/images.sha256"
ls -la "$b"
