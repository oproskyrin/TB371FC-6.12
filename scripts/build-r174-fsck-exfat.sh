#!/usr/bin/env bash
# R174: static aarch64 fsck.exfat (exfatprogs) for the 4.19 console, to repair the microSD exFAT.
set -euo pipefail
pkg=/mnt/d/TB371FC-builds/r174-bh201; mkdir -p "$pkg"
w=/root/tb371fc/exfatprogs; mkdir -p "$w"; cd "$w"
v=1.2.6
[ -f exfatprogs-$v.tar.xz ] || curl -sSLO https://github.com/exfatprogs/exfatprogs/releases/download/$v/exfatprogs-$v.tar.xz
rm -rf exfatprogs-$v; tar -xf exfatprogs-$v.tar.xz; cd exfatprogs-$v
./configure --host=aarch64-linux-gnu CC=aarch64-linux-gnu-gcc >/dev/null
make -j8 LDFLAGS=-all-static >/dev/null 2>&1
aarch64-linux-gnu-strip fsck/fsck.exfat
file fsck/fsck.exfat
cp fsck/fsck.exfat "$pkg/fsck.exfat"; sha256sum "$pkg/fsck.exfat"
