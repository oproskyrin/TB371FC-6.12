#!/bin/bash
set -euo pipefail
base=/mnt/d/TB371FC-builds/r206-redriver-id
dest=/mnt/d/TB371FC-builds/r207-ps5169
mkdir -p "$dest"
test "$(sha256sum "$base/board.dtb" | cut -d' ' -f1)" = 7b4db4c8eac248eecca28d8963991379aee9aab7942c4458faf0a9a7cc081e0f
cp "$base/Image" "$base/board.dtb" "$base/initramfs.cpio.gz" "$dest/"
d=$dest/board.dtb
wrapper=/soc@0/usb@a6f8800
core=$wrapper/usb@a600000
phy=/soc@0/phy@88e8000
hs=$(fdtget -t x "$d" /soc@0/phy@88e3000 phandle)
ss=$(fdtget -t x "$d" "$phy" phandle)
fdtput -t s "$d" "$phy" status okay
fdtput -t s "$d" "$core" maximum-speed super-speed
fdtput -t s "$d" "$core" phy-names usb2-phy usb3-phy
fdtput -t x "$d" "$core" phys "$hs" "$ss" 0
fdtput -t x "$d" "$core" reg 0 a600000 0 10000
fdtput -d "$d" "$wrapper" qcom,select-utmi-as-pipe-clk
# NB7 stays DISABLED: R206 identified physical PS5169 at9-0028.
fdtput -t s "$d" /chosen tb371fc,experiment r207-ps5169-usb3
test "$(fdtget -t s "$d" "$core" dr_mode)" = peripheral
cd "$dest"
sha256sum Image board.dtb initramfs.cpio.gz > SHA256SUMS
cat SHA256SUMS
tar -czf r207-probe-payload.tar.gz Image board.dtb initramfs.cpio.gz SHA256SUMS
