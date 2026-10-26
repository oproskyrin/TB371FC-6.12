#!/usr/bin/env bash
set -euo pipefail
p="$(cd "$(dirname "$0")/.." && pwd)"; m=/root/tb371fc/r180-regpoke; rm -rf $m; mkdir -p $m
cp "$p/scripts/r180-regpoke/tb371fc-regpoke.c" $m/; echo 'obj-m := tb371fc-regpoke.o' > $m/Kbuild
make -C /root/tb371fc/linux-6.12-r180-native O=/root/tb371fc/build-6.12-r180-native ARCH=arm64 LLVM=-18 M=$m modules > $m/build.log 2>&1 || { tail $m/build.log; exit 1; }
cp $m/tb371fc-regpoke.ko /mnt/d/TB371FC-builds/r180-native/; sha256sum /mnt/d/TB371FC-builds/r180-native/tb371fc-regpoke.ko
