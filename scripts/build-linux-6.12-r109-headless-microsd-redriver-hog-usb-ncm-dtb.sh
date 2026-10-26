#!/usr/bin/env bash
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
src=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r108-headless-microsd-redriver-hog-poll-dtb/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram-ufs-disabled-no-usb1-mmc-no-iommu-pio-redriver-hog-poll.dtb
out=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r109-headless-microsd-redriver-hog-usb-ncm-dtb
dtb=$out/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram-ufs-disabled-mmc-pio-redriver-hog-usb-ncm.dtb
wrapper=/soc/usb@a6f8800
dwc3=$wrapper/usb@a600000

bash "$project/scripts/build-linux-6.12-r108-headless-microsd-redriver-hog-poll-dtb.sh"
test -s "$src"
mkdir -p "$out"
cp --reflink=auto "$src" "$dtb"

# r98 reached the DWC3 child but looped while attaching it to SMMU group 8.
# Restore only USB1, bypass that unready IOMMU link and force device mode so
# the existing initramfs NCM rescue can provide a live log channel to the PC.
fdtput -t s "$dtb" "$wrapper" status okay
fdtput -d "$dtb" "$dwc3" iommus
fdtput -t s "$dtb" "$dwc3" dr_mode peripheral
fdtput -d "$dtb" "$dwc3" usb-role-switch
fdtput -r "$dtb" "$dwc3/ports"

test "$(fdtget -t s "$dtb" "$wrapper" status)" = okay
! fdtget "$dtb" "$dwc3" iommus >/dev/null 2>&1
test "$(fdtget -t s "$dtb" "$dwc3" dr_mode)" = peripheral
! fdtget "$dtb" "$dwc3" usb-role-switch >/dev/null 2>&1
! fdtget -l "$dtb" "$dwc3" | grep -qx ports
! fdtget "$dtb" /soc/mmc@8804000 redriver-power-gpios >/dev/null 2>&1
fdtget "$dtb" /soc/pinctrl@f100000/sd-redriver-hog output-high >/dev/null
test "$(fdtget -t x "$dtb" /soc/pinctrl@f100000/sd-redriver-hog gpios)" = "4b 0"
test "$(fdtget -t x "$dtb" /soc/mmc@8804000 sdhci-caps-mask)" = "0 480000"
test "$(fdtget -t s "$dtb" /soc/ufshc@1d84000 status)" = disabled
sha256sum "$dtb"
