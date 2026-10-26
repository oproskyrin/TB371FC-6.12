#!/usr/bin/env bash
# R155 DT: R154 DT (SD non-removable) + microSD DMA restored.
# R105 removed `iommus` and set sdhci-caps-mask=0x00480000 (no SDMA/ADMA2 -> PIO) only as
# a probe-debug hypothesis that did not change the result; the card was later fixed by
# other changes. In PIO a 16 GB write starved the system (R154 tests). Restore the
# upstream sm8250.dtsi values: iommus = <&apps_smmu 0x4a0 0x0>, no caps mask.
set -euo pipefail
base=/mnt/d/TB371FC-builds/r154-persist/board.dtb
pkg=/mnt/d/TB371FC-builds/r155-sd-dma
d="$pkg/board.dtb"
mmc=/soc@0/mmc@8804000
smmu=/soc@0/iommu@15000000
mkdir -p "$pkg"; test ! -e "$d"
test "$(sha256sum "$base" | cut -d' ' -f1)" = d0e835b52ba54990dc7653e9f1fee865e7462c47fe73799b4c6ce54635d5046b
cp "$base" "$d"
test "$(fdtget -t x "$d" $mmc sdhci-caps-mask)" = "0 480000"
! fdtget "$d" $mmc iommus >/dev/null 2>&1
test "$(fdtget -t s "$d" $smmu compatible | head -1)" != ""
ph=$(fdtget -t x "$d" $smmu phandle)
test "$ph" = 31          # same SMMU phandle that USB/PCIe already use
fdtput -d "$d" $mmc sdhci-caps-mask
fdtput -t x "$d" $mmc iommus "$ph" 4a0 0
dtc -q -s -I dtb -O dts "$base" > "$pkg/baseline-r154.dts"
dtc -q -s -I dtb -O dts "$d" > "$pkg/candidate.dts"
diff -u "$pkg/baseline-r154.dts" "$pkg/candidate.dts" > "$pkg/dtb.diff" || test "$?" = 1
cat "$pkg/dtb.diff"
sha256sum "$d"
