#!/usr/bin/env bash
# R148: exact R140 Image/initramfs/DT plus two touch-only DT edits:
#  - /soc@0/geniqup@8c0000/spi@880000 and its touchscreen@0 child: status = okay
#  - TLMM gpio-reserved-ranges: additionally free gpio40-43 (qup14 SPI), 56 (TP reset),
#    68 (TP irq), 82 (panel id). Everything else stays reserved (gpio75 already free).
set -euo pipefail
base=/mnt/d/TB371FC-builds/checkpoints/r140-arch612-mmcx-kde-software-20261024
pkg=/mnt/d/TB371FC-builds/r148-touch
spi=/soc@0/geniqup@8c0000/spi@880000
tlmm=/soc@0/pinctrl@f100000
mkdir -p "$pkg"
test ! -e "$pkg/board.dtb"
(cd "$base"; grep -E " (Image|board.dtb|initramfs.cpio.gz)$" SHA256SUMS | sha256sum -c -)
cp "$base/Image" "$base/initramfs.cpio.gz" "$base/board.dtb" "$pkg/"
d="$pkg/board.dtb"
test "$(fdtget -t s "$d" $spi status)" = disabled
test "$(fdtget -t s "$d" $spi/touchscreen@0 compatible)" = novatek,NVT-ts-spi
test "$(fdtget -t s "$d" $spi/touchscreen@0 status)" = disabled
test "$(fdtget -t u "$d" $tlmm gpio-reserved-ranges)" = "0 75 76 105"
test "$(fdtget -t x "$d" $tlmm gpio-ranges)" = "3b 0 0 b5"
fdtput -t s "$d" $spi status okay
fdtput -t s "$d" $spi/touchscreen@0 status okay
# No ICC provider is loaded in R140; keep the bootloader QUP bandwidth (as R130 USB did).
icc=$(fdtget -t x "$d" $spi interconnects); iccn=$(fdtget -t s "$d" $spi interconnect-names)
fdtput -d "$d" $spi interconnects
fdtput -d "$d" $spi interconnect-names
# reserved: 0-39, 44-55, 57-67, 69-74, 76-81, 83-180  (181 GPIOs total)
fdtput -t u "$d" $tlmm gpio-reserved-ranges 0 40 44 12 57 11 69 6 76 6 83 98
dtc -q -s -I dtb -O dts "$base/board.dtb" > "$pkg/baseline-r140.dts"
dtc -q -s -I dtb -O dts "$d" > "$pkg/candidate.dts"
diff -u "$pkg/baseline-r140.dts" "$pkg/candidate.dts" > "$pkg/dtb.diff" || test "$?" = 1
cp "$d" "$pkg/rt.dtb"
fdtput -t s "$pkg/rt.dtb" $spi status disabled
fdtput -t s "$pkg/rt.dtb" $spi/touchscreen@0 status disabled
fdtput -t x "$pkg/rt.dtb" $spi interconnects $icc
fdtput -t s "$pkg/rt.dtb" $spi interconnect-names qup-core qup-config qup-memory
fdtput -t u "$pkg/rt.dtb" $tlmm gpio-reserved-ranges 0 75 76 105
dtc -q -s -I dtb -O dts "$pkg/rt.dtb" > "$pkg/rt.dts"; cmp "$pkg/baseline-r140.dts" "$pkg/rt.dts"
rm "$pkg/rt.dtb" "$pkg/rt.dts"
cd "$pkg"
sha256sum Image board.dtb initramfs.cpio.gz nt36523_ts.ko > SHA256SUMS.payload
tar -czf r148-payload.tar.gz Image board.dtb initramfs.cpio.gz
sha256sum r148-payload.tar.gz >> SHA256SUMS.payload
cat SHA256SUMS.payload dtb.diff
