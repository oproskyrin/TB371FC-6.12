#!/usr/bin/env bash
# R174: static aarch64 e2fsprogs (e2fsck, resize2fs, tune2fs, mke2fs) for the RAM-only maintenance mode.
set -euo pipefail
pkg=/mnt/d/TB371FC-builds/r174-bh201; mkdir -p "$pkg/maint"
w=/root/tb371fc/e2fsprogs; mkdir -p "$w"; cd "$w"
v=1.47.1
[ -f e2fsprogs-$v.tar.xz ] || curl -sSLO https://mirrors.edge.kernel.org/pub/linux/kernel/people/tytso/e2fsprogs/v$v/e2fsprogs-$v.tar.xz
rm -rf e2fsprogs-$v; tar -xf e2fsprogs-$v.tar.xz; cd e2fsprogs-$v
./configure --host=aarch64-linux-gnu CC=aarch64-linux-gnu-gcc LDFLAGS=-static --disable-nls --disable-fuse2fs --disable-elf-shlibs >/dev/null
make -j8 >/dev/null 2>&1
for b in e2fsck/e2fsck resize/resize2fs misc/tune2fs misc/mke2fs; do aarch64-linux-gnu-strip $b; file $b | cut -c1-110; cp $b "$pkg/maint/"; done
cp /root/tb371fc/exfatprogs/exfatprogs-1.2.6/mkfs/mkfs.exfat "$pkg/maint/"; aarch64-linux-gnu-strip "$pkg/maint/mkfs.exfat"
cp "$pkg/fsck.exfat" "$pkg/tb371fc-bh201.ko" "$pkg/maint/"
ls -la "$pkg/maint"
