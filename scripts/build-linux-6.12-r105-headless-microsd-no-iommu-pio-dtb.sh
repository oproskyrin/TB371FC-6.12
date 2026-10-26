#!/usr/bin/env bash
set -euo pipefail

src=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r101-headless-microsd-inherited-power-dtb/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram-ufs-disabled-no-usb1-mmc-inherited-power.dtb
out=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r105-headless-microsd-no-iommu-pio-dtb
dtb=$out/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram-ufs-disabled-no-usb1-mmc-no-iommu-pio.dtb

test -s "$src"
mkdir -p "$out"
cp --reflink=auto "$src" "$dtb"

# r104 proved that the platform device had neither a driver nor iommu_group.
# Remove only the external SD controller's IOMMU attachment and mask both
# integrated DMA capability bits so the first no-IOMMU probe is PIO-only.
fdtput -d "$dtb" /soc/mmc@8804000 iommus
fdtput -t x "$dtb" /soc/mmc@8804000 sdhci-caps-mask 0x0 0x00480000

! fdtget "$dtb" /soc/mmc@8804000 iommus >/dev/null 2>&1
test "$(fdtget -t x "$dtb" /soc/mmc@8804000 sdhci-caps-mask)" = "0 480000"
test "$(fdtget -t s "$dtb" /soc/mmc@8804000 status)" = okay
test "$(fdtget -t x "$dtb" /soc/mmc@8804000 max-frequency)" = 17d7840
test "$(fdtget -t x "$dtb" /soc/mmc@8804000 bus-width)" = 4
test "$(fdtget -t s "$dtb" /soc/ufshc@1d84000 status)" = disabled
test "$(fdtget -t s "$dtb" /soc/usb@a6f8800 status)" = disabled
sha256sum "$dtb"
