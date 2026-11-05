#!/bin/bash
# RAM boot candidate: exact R226 Image/initrd, only DWC3 role properties change.
set -euo pipefail
base=/mnt/d/TB371FC-builds/r226-v2-timerfix
dest=/mnt/d/TB371FC-builds/r228-otg-test
mkdir -p "$dest"
cd "$base"
sha256sum -c SHA256SUMS
cp Image initramfs.cpio.gz "$dest/"
cp board-usb3.dtb "$dest/board.dtb"
core=/soc@0/usb@a6f8800/usb@a600000
fdtput -t s "$dest/board.dtb" "$core" dr_mode otg
fdtput "$dest/board.dtb" "$core" usb-role-switch
fdtput -t s "$dest/board.dtb" "$core" role-switch-default-mode peripheral
fdtput -t s "$dest/board.dtb" /chosen tb371fc,host-test r228-otg
dtc -q -s -I dtb -O dts "$base/board-usb3.dtb" > "$dest/base.dts"
dtc -q -s -I dtb -O dts "$dest/board.dtb" > "$dest/candidate.dts"
diff -u "$dest/base.dts" "$dest/candidate.dts" > "$dest/dt.diff" || test "$?" = 1
cd "$dest"
sha256sum Image board.dtb initramfs.cpio.gz > SHA256SUMS
tar -czf r228-otg-payload.tar.gz Image board.dtb initramfs.cpio.gz SHA256SUMS
cat SHA256SUMS
cat dt.diff
echo 'R228 BUILT ONLY: default DEVICE; no TCPM/VBUS enable, no permanent install'
