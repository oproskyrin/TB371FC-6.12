#!/usr/bin/env bash
# R184 DT (test): R178 DT + battery fuel gauge. The Lenovo DT puts a Mitsumi MM8013 on
# qupv3_se3_i2c (mainline i2c3, 0x98c000, GPIO 119/120) at 0x55; our early bring-up reserved
# GPIO 119..137, so i2c3 failed to probe. Free GPIO 119/120 only and make sure the gauge node exists.
set -euo pipefail
base=/mnt/d/TB371FC-builds/r178-autoboot/board.dtb
pkg=/mnt/d/TB371FC-builds/r184-battery; mkdir -p "$pkg"; d=$pkg/board.dtb
tlmm=/soc@0/pinctrl@f100000; i2c=/soc@0/geniqup@9c0000/i2c@98c000
sha256sum "$base"
fdtget -t u "$base" $tlmm gpio-reserved-ranges
fdtget "$base" $i2c status || true
fdtget -l "$base" $i2c || true
cp "$base" "$d"
old=$(fdtget -t u "$base" $tlmm gpio-reserved-ranges)
new=$(echo "$old" | sed 's/ 119 19 / 121 17 /')
[ "$old" != "$new" ]
fdtput -t u "$d" $tlmm gpio-reserved-ranges $new
fdtput -t s "$d" $i2c status okay
# like the working i2c@994000: the QUP interconnect (qup_virt) is not provided by this 6.12 tree
fdtput -d "$d" $i2c interconnects; fdtput -d "$d" $i2c interconnect-names
fdtget "$d" $i2c/fuel-gauge@55 compatible 2>/dev/null || { fdtput -c "$d" $i2c/fuel-gauge@55; fdtput -t s "$d" $i2c/fuel-gauge@55 compatible mitsumi,mm8013; fdtput -t x "$d" $i2c/fuel-gauge@55 reg 55; }
fdtget -t u "$d" $tlmm gpio-reserved-ranges
fdtget "$d" $i2c/fuel-gauge@55 compatible
dtc -q -s -I dtb -O dts "$base" > "$pkg/base.dts"; dtc -q -s -I dtb -O dts "$d" > "$pkg/r184.dts"; diff -u "$pkg/base.dts" "$pkg/r184.dts" || true
sha256sum "$d"
# fuel gauge driver as a module (CONFIG_FUEL_GAUGE_MM8013 is off in the R179 kernel)
src=/root/tb371fc/linux-6.12-donor-r118; out=/root/tb371fc/build-6.12-r159-audio
m=/root/tb371fc/r184-mm8013; rm -rf "$m"; mkdir -p "$m"; cp "$src/drivers/power/supply/mm8013.c" "$m/"; echo 'obj-m := mm8013.o' > "$m/Kbuild"
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 M="$m" modules 2>&1 | tail -3
modinfo -F vermagic "$m/mm8013.ko"; modinfo -F depends "$m/mm8013.ko"; cp "$m/mm8013.ko" "$pkg/"
