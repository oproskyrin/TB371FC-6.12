#!/usr/bin/env bash
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
src=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r105-headless-microsd-no-iommu-pio-dtb/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram-ufs-disabled-no-usb1-mmc-no-iommu-pio.dtb
out=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r106-headless-microsd-inherited-pins-poll-dtb
dtb=$out/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram-ufs-disabled-no-usb1-mmc-no-iommu-pio-inherited-pins-poll.dtb

bash "$project/scripts/build-linux-6.12-r105-headless-microsd-no-iommu-pio-dtb.sh"
test -s "$src"
mkdir -p "$out"
cp --reflink=auto "$src" "$dtb"

# r105 still deferred before the first sdhci-msm reset/clock diagnostic.
# Avoid all early card-detect/pinctrl GPIO acquisition and retain the pin state
# inherited from the working 4.19 first stage. Poll for the removable card.
for prop in cd-gpios pinctrl-names pinctrl-0 pinctrl-1 redriver-power-gpios; do
  fdtput -d "$dtb" /soc/mmc@8804000 "$prop"
done
fdtput "$dtb" /soc/mmc@8804000 broken-cd

for prop in cd-gpios pinctrl-names pinctrl-0 pinctrl-1 redriver-power-gpios; do
  ! fdtget "$dtb" /soc/mmc@8804000 "$prop" >/dev/null 2>&1
done
fdtget "$dtb" /soc/mmc@8804000 broken-cd >/dev/null
! fdtget "$dtb" /soc/mmc@8804000 iommus >/dev/null 2>&1
test "$(fdtget -t x "$dtb" /soc/mmc@8804000 sdhci-caps-mask)" = "0 480000"
test "$(fdtget -t s "$dtb" /soc/mmc@8804000 status)" = okay
test "$(fdtget -t s "$dtb" /soc/ufshc@1d84000 status)" = disabled
test "$(fdtget -t s "$dtb" /soc/usb@a6f8800 status)" = disabled
sha256sum "$dtb"
