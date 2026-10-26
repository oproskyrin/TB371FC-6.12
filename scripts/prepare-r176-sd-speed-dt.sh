#!/usr/bin/env bash
# R176 DT (test): R171 DT + microSD speed: High Speed at 50 MHz (was capped at 25 MHz by
# max-frequency) and DMA restored (iommus <&apps_smmu 0x4a0 0>, no sdhci-caps-mask; R155 showed
# ADMA reads work, R155 writes failed only because the IO pads were still in 3.0 V mode).
# Variants: dma50 (both), dma25 (DMA only), pio50 (50 MHz only).
set -euo pipefail
base=/mnt/d/TB371FC-builds/r171-bt/board.dtb
pkg=/mnt/d/TB371FC-builds/r176-sd-speed; mkdir -p "$pkg"
mmc=/soc@0/mmc@8804000; smmu=/soc@0/iommu@15000000
test "$(sha256sum "$base" | cut -d' ' -f1)" = d341922a8ee8393b95637933751f1ea5584bb9659bed3ea32ebcb85818876ca2
test "$(fdtget -t x "$base" $mmc sdhci-caps-mask)" = "0 480000"
test "$(fdtget -t u "$base" $mmc max-frequency)" = 25000000
ph=$(fdtget -t x "$base" $smmu phandle); echo "smmu phandle $ph"
for v in dma50 dma25 pio50; do
  d="$pkg/board-$v.dtb"; cp "$base" "$d"
  case $v in dma*) fdtput -d "$d" $mmc sdhci-caps-mask; fdtput -t x "$d" $mmc iommus "$ph" 4a0 0;; esac
  case $v in *50) fdtput -t u "$d" $mmc max-frequency 50000000;; esac
  dtc -q -s -I dtb -O dts "$d" > "$pkg/$v.dts"
  sha256sum "$d"
done
dtc -q -s -I dtb -O dts "$base" > "$pkg/baseline.dts"; diff -u "$pkg/baseline.dts" "$pkg/dma50.dts" || true
