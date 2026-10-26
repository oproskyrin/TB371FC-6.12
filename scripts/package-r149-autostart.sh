#!/usr/bin/env bash
# R149: R148 (R140 Image + touch DT) with an initramfs that auto-starts the
# touchscreen (calibrated) and KDE Plasma on tty7 after the existing R130 USB/SSH.
set -euo pipefail
project="$(cd "$(dirname "$0")/.." && pwd)"
base=/mnt/d/TB371FC-builds/r148-touch
pkg=/mnt/d/TB371FC-builds/r149b-autostart
cfg="$project/scripts/r149-config"
test ! -e "$pkg"
(cd "$base"; grep -E " (Image|board.dtb|initramfs.cpio.gz|nt36523_ts.ko)$" SHA256SUMS.payload | sha256sum -c -)
mkdir "$pkg"
cp "$base/Image" "$base/board.dtb" "$base/nt36523_ts.ko" "$pkg/"
stage=$(mktemp -d /root/tb371fc/r149-initramfs.XXXXXX)
echo "$stage" > "$pkg/staging-path.txt"
(cd "$stage"; gzip -dc "$base/initramfs.cpio.gz" | cpio -idmu --quiet)
# Expected R130 layout.
# The loader installs /r129-config/r129-evidence.sh as the boot hook (R130 after-arch copy).
ev="$stage/r129-config/r129-evidence.sh"
grep -q '/r129-config/r129-evidence.sh /newroot/usr/local/sbin/tb371fc-r129-evidence' "$stage/bin/boot-arch-r129-base"
tail -1 "$ev" | grep -q '^systemctl --no-block start r130-usb.service$'
grep -q 'cp /r130-modules/\*.ko /run/r130/modules/' "$stage/r130-config/boot-wrapper.sh"
test ! -e "$stage/r130-config/id_ed25519"
cp "$base/nt36523_ts.ko" "$stage/r130-modules/"
cp "$cfg/99-tb371fc-touch.rules" "$cfg/r149-touch.service" "$cfg/r149-plasma.service" "$cfg/r149-install.sh" "$stage/r130-config/"
for f in r149-install.sh; do sed -i 's/\r$//' "$stage/r130-config/$f"; sh -n "$stage/r130-config/$f"; done
sed -i 's/\r$//' "$stage/r130-config/"r149-*.service "$stage/r130-config/99-tb371fc-touch.rules"
printf '/run/r130/busybox sh /run/r130/config/r149-install.sh\n' >> "$ev"
sh -n "$ev"
tail -3 "$ev"
(cd "$stage"; find . -print0 | sort -z | cpio --null -o --format=newc --owner=0:0 --quiet | gzip -9n) > "$pkg/initramfs.cpio.gz"
cd "$pkg"
sha256sum Image board.dtb initramfs.cpio.gz nt36523_ts.ko > SHA256SUMS
tar -czf r149b-payload.tar.gz Image board.dtb initramfs.cpio.gz
sha256sum r149b-payload.tar.gz >> SHA256SUMS
cat SHA256SUMS
