#!/usr/bin/env bash
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
src=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r106-headless-microsd-inherited-pins-poll-dtb/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram-ufs-disabled-no-usb1-mmc-no-iommu-pio-inherited-pins-poll.dtb
out=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r107-headless-microsd-redriver-poll-dtb
dtb=$out/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram-ufs-disabled-no-usb1-mmc-no-iommu-pio-redriver-poll.dtb

bash "$project/scripts/build-linux-6.12-r106-headless-microsd-inherited-pins-poll-dtb.sh"
test -s "$src"
mkdir -p "$out"
cp --reflink=auto "$src" "$dtb"

# r106 bound sdhci_msm and created mmc0 in PIO, but no card responded.
# Restore only the external signal-redriver enable GPIO. Card-detect and
# pinctrl remain inherited/polled, so the proven early-probe fix is preserved.
fdtput -t x "$dtb" /soc/mmc@8804000 redriver-power-gpios 0x3b 0x4b 0x0

test "$(fdtget -t x "$dtb" /soc/mmc@8804000 redriver-power-gpios)" = "3b 4b 0"
for prop in cd-gpios pinctrl-names pinctrl-0 pinctrl-1 iommus; do
  ! fdtget "$dtb" /soc/mmc@8804000 "$prop" >/dev/null 2>&1
done
fdtget "$dtb" /soc/mmc@8804000 broken-cd >/dev/null
test "$(fdtget -t x "$dtb" /soc/mmc@8804000 sdhci-caps-mask)" = "0 480000"
test "$(fdtget -t s "$dtb" /soc/ufshc@1d84000 status)" = disabled
test "$(fdtget -t s "$dtb" /soc/usb@a6f8800 status)" = disabled
sha256sum "$dtb"
