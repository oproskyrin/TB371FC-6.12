#!/usr/bin/env bash
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
src=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r108-headless-microsd-redriver-hog-poll-dtb/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram-ufs-disabled-no-usb1-mmc-no-iommu-pio-redriver-hog-poll.dtb
out=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r115-microsd-redriver-pwrseq-dtb
dtb=$out/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram-ufs-disabled-no-usb1-mmc-no-iommu-pio-redriver-pwrseq.dtb
mmc=/soc/mmc@8804000
tlmm=/soc/pinctrl@f100000
hog=$tlmm/sd-redriver-hog
pwrseq=/sd-redriver-pwrseq

bash "$project/scripts/build-linux-6.12-r108-headless-microsd-redriver-hog-poll-dtb.sh"
test -s "$src"
mkdir -p "$out"
cp --reflink=auto "$src" "$dtb"

# r114 proved that CMD0 is issued but CMD8/CMD55 receive no response. Replace
# the always-high redriver GPIO hog with the standard MMC power-sequence
# provider. GPIO_ACTIVE_LOW makes probe assert the redriver enable physically
# low; post_power_on then deasserts it physically high before the first command.
fdtput -r "$dtb" "$hog"
fdtput -c "$dtb" "$pwrseq"
fdtput -t s "$dtb" "$pwrseq" compatible mmc-pwrseq-simple
fdtput -t x "$dtb" "$pwrseq" phandle 0x121
fdtput -t x "$dtb" "$pwrseq" reset-gpios 0x3b 0x4b 0x1
fdtput -t u "$dtb" "$pwrseq" post-power-on-delay-ms 10
fdtput -t u "$dtb" "$pwrseq" power-off-delay-us 1000
fdtput -t x "$dtb" "$mmc" mmc-pwrseq 0x121

! fdtget "$dtb" "$hog" gpio-hog >/dev/null 2>&1
test "$(fdtget -t s "$dtb" "$pwrseq" compatible)" = mmc-pwrseq-simple
test "$(fdtget -t x "$dtb" "$pwrseq" phandle)" = 121
test "$(fdtget -t x "$dtb" "$pwrseq" reset-gpios)" = '3b 4b 1'
test "$(fdtget -t u "$dtb" "$pwrseq" post-power-on-delay-ms)" = 10
test "$(fdtget -t u "$dtb" "$pwrseq" power-off-delay-us)" = 1000
test "$(fdtget -t x "$dtb" "$mmc" mmc-pwrseq)" = 121
fdtget "$dtb" "$mmc" no-1-8-v >/dev/null
test "$(fdtget -t x "$dtb" "$mmc" max-frequency)" = 17d7840
test "$(fdtget -t s "$dtb" /soc/ufshc@1d84000 status)" = disabled
test "$(fdtget -t s "$dtb" /soc/usb@a6f8800 status)" = disabled
sha256sum "$dtb"
