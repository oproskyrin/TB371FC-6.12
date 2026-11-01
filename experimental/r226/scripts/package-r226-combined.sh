#!/bin/bash
set -euo pipefail
p='/mnt/c/Users/Sailren/Documents/ChatGPT/linux lenovo'
base=/mnt/d/TB371FC-builds/r224-sd150
dest=${R226_DEST:-/mnt/d/TB371FC-builds/r226-combined-candidate}
mkdir -p "$dest"
cd "$base"
sha256sum -c SHA256SUMS
cp Image "$dest/"
cp board.dtb "$dest/board-usb2.dtb"
# Exact R209 known-working USB DT, retaining all existing display/touch nodes.
cp /mnt/d/TB371FC-builds/r207-ps5169/board.dtb "$dest/board-usb3.dtb"
test "$(sha256sum "$dest/board-usb3.dtb" | cut -d' ' -f1)" = 308ee4e6d30e3fed6a71c1260418b8761f2ef366c9f8c759641ff341675ebb80
for dt in "$dest/board-usb2.dtb" "$dest/board-usb3.dtb"; do
 fdtput -t x "$dt" /chosen tb371fc,sd150 1
 fdtput -t s "$dt" /chosen tb371fc,release r226-candidate
done
stage=$(mktemp -d /root/tb371fc/r226-initrd.XXXXXX)
cd "$stage"
gzip -dc "$base/initramfs.cpio.gz" | cpio -id --quiet
mkdir r226
cp /mnt/d/TB371FC-builds/r225-touch-pm/r225-touch-pm.ko r226/
cp /mnt/d/TB371FC-builds/r209-usb3-enumeration-candidate/modules/*.ko r226/
cp "$p/scripts/"{r226-touch-ready.sh,r226-touch-ready.service,r226-touch-ready.timer,r226-usb3-ready.sh,r226-usb3-ready.service,r203-retry-usb-gadget.sh} r226/
python3 "$p/scripts/prepare-r226-initrd.py" "$stage"
find . -print0 | sort -z | cpio --null -o -H newc -R 0:0 --quiet | gzip -9 > "$dest/initramfs.cpio.gz"
cd "$dest"
sha256sum Image board-usb2.dtb board-usb3.dtb initramfs.cpio.gz > SHA256SUMS
tar -czf r226-combined-payload.tar.gz Image board-usb2.dtb board-usb3.dtb initramfs.cpio.gz SHA256SUMS
cat SHA256SUMS
echo 'R226 CANDIDATE ONLY: not installed, fixed USB3 orientation; fresh boot verification required'
