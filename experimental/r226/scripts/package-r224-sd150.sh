#!/bin/bash
set -euo pipefail
p='/mnt/c/Users/Sailren/Documents/ChatGPT/linux lenovo'
src=/root/tb371fc/linux-6.12.114-r200
out=/root/tb371fc/build-6.12.114-r200
dest=/mnt/d/TB371FC-builds/r224-sd150
base=/mnt/d/TB371FC-builds/r201-display
work=$(mktemp -d /root/tb371fc/r224-boot-module.XXXXXX)
cp "$p/scripts/r224-sd150-boot/"* "$work/"
cp "$src/drivers/mmc/host/sdhci.h" "$work/"
make -C "$out" ARCH=arm64 LLVM=-18 M="$work" modules
cp "$work/r224-sd150-boot.ko" "$dest/"
test "$(sha256sum "$base/initramfs.cpio.gz" | cut -d' ' -f1)" = 7aae7512d97d6b1ed4acea64360e9fc5e0b55cac7553d5d9ca0c24642546ec2d
cp "$base/board.dtb" "$dest/"
fdtput -t x "$dest/board.dtb" /chosen tb371fc,sd150 1
stage=$(mktemp -d /root/tb371fc/r224-initrd.XXXXXX)
cd "$stage"
gzip -dc "$base/initramfs.cpio.gz" | cpio -id --quiet
cp "$dest/r224-sd150-boot.ko" usr/maint/
python3 "$p/scripts/prepare-r224-initrd.py" "$stage"
find . -print0 | sort -z | cpio --null -o -H newc -R 0:0 --quiet | gzip -9 > "$dest/initramfs.cpio.gz"
cd "$dest"
sha256sum Image board.dtb initramfs.cpio.gz r224-sd150-boot.ko > SHA256SUMS
tar -czf r224-sd150-payload.tar.gz Image board.dtb initramfs.cpio.gz r224-sd150-boot.ko SHA256SUMS
cat SHA256SUMS
