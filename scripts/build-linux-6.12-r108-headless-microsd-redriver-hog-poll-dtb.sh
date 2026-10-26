#!/usr/bin/env bash
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
src=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r106-headless-microsd-inherited-pins-poll-dtb/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram-ufs-disabled-no-usb1-mmc-no-iommu-pio-inherited-pins-poll.dtb
out=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r108-headless-microsd-redriver-hog-poll-dtb
dtb=$out/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram-ufs-disabled-no-usb1-mmc-no-iommu-pio-redriver-hog-poll.dtb
hog=/soc/pinctrl@f100000/sd-redriver-hog

bash "$project/scripts/build-linux-6.12-r106-headless-microsd-inherited-pins-poll-dtb.sh"
test -s "$src"
mkdir -p "$out"
cp --reflink=auto "$src" "$dtb"

# r107 proved that an MMC redriver GPIO consumer defers before sdhci_msm can
# bind. Keep the hardware-proven r106 MMC node dependency-free and assert GPIO
# 75 from the TLMM provider itself. A GPIO hog has no supplier link from MMC.
fdtput -c "$dtb" "$hog"
fdtput "$dtb" "$hog" gpio-hog
fdtput -t x "$dtb" "$hog" gpios 0x4b 0x0
fdtput "$dtb" "$hog" output-high
fdtput -t s "$dtb" "$hog" line-name tb371fc-sd-redriver-enable

! fdtget "$dtb" /soc/mmc@8804000 redriver-power-gpios >/dev/null 2>&1
fdtget "$dtb" "$hog" gpio-hog >/dev/null
test "$(fdtget -t x "$dtb" "$hog" gpios)" = "4b 0"
fdtget "$dtb" "$hog" output-high >/dev/null
test "$(fdtget -t s "$dtb" "$hog" line-name)" = tb371fc-sd-redriver-enable
for prop in cd-gpios pinctrl-names pinctrl-0 pinctrl-1 iommus; do
  ! fdtget "$dtb" /soc/mmc@8804000 "$prop" >/dev/null 2>&1
done
fdtget "$dtb" /soc/mmc@8804000 broken-cd >/dev/null
test "$(fdtget -t x "$dtb" /soc/mmc@8804000 sdhci-caps-mask)" = "0 480000"
test "$(fdtget -t s "$dtb" /soc/ufshc@1d84000 status)" = disabled
test "$(fdtget -t s "$dtb" /soc/usb@a6f8800 status)" = disabled
sha256sum "$dtb"
