#!/bin/bash
# R185 (RAM test): R179 headless-GPU payload, GPU SMMU without "qcom,adreno-smmu".
# R183 showed CP translation faults on userspace IBs (per-process page tables, TTBR0 switching).
# Without the adreno-smmu impl msm cannot create per-process page tables and falls back to the
# global GPU address space: no TTBR switching by the CP at all. Diagnostic, not a final design.
set -euo pipefail
base=/mnt/d/TB371FC-builds/r179-autoboot
dest=/mnt/d/TB371FC-builds/r185-gpu-global; rm -rf "$dest"; mkdir -p "$dest"
cp "$base/Image" "$base/board.dtb" "$base/initramfs.cpio.gz" "$dest/"
n=/soc@0/iommu@3da0000
test "$(fdtget "$dest/board.dtb" $n compatible)" = "qcom,sm8250-smmu-500 qcom,adreno-smmu qcom,smmu-500 arm,mmu-500"
fdtput -t s "$dest/board.dtb" $n compatible qcom,sm8250-smmu-500 qcom,smmu-500 arm,mmu-500
fdtget "$dest/board.dtb" $n compatible
cd "$dest"; sha256sum Image board.dtb initramfs.cpio.gz | tee SHA256SUMS
tar -czf r185-payload.tar.gz Image board.dtb initramfs.cpio.gz
