#!/usr/bin/env bash
# R153 DT: R151 (touch + Wi-Fi) DT + Lenovo magnetic keyboard cover (I2C-HID 17ef:6175
# at QUP SE13 i2c@a94000, addr 0x60). The node already exists; this only:
#  - removes interconnects from i2c@a94000 (no ICC provider in this kernel; it would defer)
#  - frees gpio36/37 (qup13 SDA/SCL), 108 (wake), 110 (irq), 114 (reset) in TLMM.
set -euo pipefail
base=/mnt/d/TB371FC-builds/r151-wifi/board.dtb
pkg=/mnt/d/TB371FC-builds/r153-keyboard
d="$pkg/board.dtb"
i2c=/soc@0/geniqup@ac0000/i2c@a94000
tlmm=/soc@0/pinctrl@f100000
mkdir -p "$pkg"; test ! -e "$d"
test "$(sha256sum "$base" | cut -d' ' -f1)" = 1e6151687b740dd65a5a51e0a690b7f32ecc9399b868c238d8fae2f27776c5a6
cp "$base" "$d"
test "$(fdtget -t s "$d" $i2c status)" = okay
test "$(fdtget -t s "$d" $i2c/keyboard-cover@60 compatible)" = hid-over-i2c
test "$(fdtget -t x "$d" $i2c/keyboard-cover@60 reset-gpios)" = "3b 72 1"
test "$(fdtget -t x "$d" $i2c/keyboard-cover@60 wake-gpios)" = "3b 6c 0"
test "$(fdtget -t x "$d" $i2c/keyboard-cover@60 interrupts)" = "6e 8"
test "$(fdtget -t u "$d" $tlmm gpio-reserved-ranges)" = "0 20 22 18 44 12 57 11 69 6 76 3 83 98"
fdtput -d "$d" $i2c interconnects
fdtput -d "$d" $i2c interconnect-names
# reserved: 0-19, 22-35, 38-39, 44-55, 57-67, 69-74, 76-78, 83-107, 109, 111-113, 115-180
fdtput -t u "$d" $tlmm gpio-reserved-ranges 0 20 22 14 38 2 44 12 57 11 69 6 76 3 83 25 109 1 111 3 115 66
dtc -q -s -I dtb -O dts "$base" > "$pkg/baseline-r151.dts"
dtc -q -s -I dtb -O dts "$d" > "$pkg/candidate.dts"
diff -u "$pkg/baseline-r151.dts" "$pkg/candidate.dts" > "$pkg/dtb.diff" || test "$?" = 1
cat "$pkg/dtb.diff"
sha256sum "$d"
