#!/bin/bash
# Offline DT diagnostic only; no flash, rootfs or SD writes.
# Enable access only to GPIO0/1 already assigned to stock QUP19 I2C.
set -euo pipefail
base=/mnt/d/TB371FC-builds/r226-v2-timerfix/board-usb3.dtb
dest=/mnt/d/TB371FC-builds/r234-fsa-bus
mkdir -p "$dest"
dt=$dest/board.dtb
cp "$base" "$dt"
test "$(sha256sum "$base" | cut -d' ' -f1)" = d061e7e3445936db745308098a625fe060a69d6874840ded62cb110b5f18f775
pin=/soc@0/pinctrl@f100000
bus=/soc@0/geniqup@8c0000/i2c@894000
test "$(fdtget -t s "$dt" "$bus" status)" = okay
test "$(fdtget -t s "$dt" "$pin/qup-i2c19-default-state" function)" = qup19
test "$(fdtget -t s "$dt" "$pin/qup-i2c19-default-state" pins)" = 'gpio0 gpio1'
read -ra reserved <<< "$(fdtget -t x "$dt" "$pin" gpio-reserved-ranges)"
test "${reserved[0]}" = 0
test "${reserved[1]}" = c
# Preserve every other reserved pin. Old0..11 becomes2..11.
reserved[0]=2
reserved[1]=a
fdtput -t x "$dt" "$pin" gpio-reserved-ranges "${reserved[@]}"
# Do not probe a switch driver until its identity is read back first.
fdtput -t s "$dt" "$bus/typec-mux@42" status disabled
fdtput -t s "$dt" /chosen tb371fc,r234-test fsa-bus-readonly
dtc -q -I dtb -O dts -o "$dest/board.dts" "$dt"
dtc -q -I dtb -O dts -o "$dest/base.dts" "$base"
diff -u "$dest/base.dts" "$dest/board.dts" > "$dest/DT.diff" || test "$?" = 1
for file in Image initramfs.cpio.gz; do
    cp "/mnt/d/TB371FC-builds/r226-v2-timerfix/$file" "$dest/"
done
cd "$dest"
test "$(sha256sum Image | cut -d' ' -f1)" = 7a59c7b2931c8e8925446a3cec5432a0912d5f0e3f9365058de2492ad6d0d157
test "$(sha256sum initramfs.cpio.gz | cut -d' ' -f1)" = 0bcad91fa94af6ee794b85c52da12180709c729690a992864090981dc75f1219
sha256sum Image board.dtb initramfs.cpio.gz > SHA256SUMS
tar -czf r234-fsa-bus-payload.tar.gz Image board.dtb initramfs.cpio.gz SHA256SUMS
sha256sum "$dt"
cat "$dest/DT.diff"
