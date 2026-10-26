#!/bin/bash
set -euo pipefail
base=/mnt/d/TB371FC-builds/r179-autoboot
dest=/mnt/d/TB371FC-builds/r183-acceleration/noncoherent
mkdir -p "$dest"
cp "$base/Image" "$base/board.dtb" "$base/initramfs.cpio.gz" "$dest/"
# Diagnostic only: force explicit CPU cache maintenance of GPU page tables.
# No change to the display, SD, system SMMU, or installed boot files.
fdtput -d "$dest/board.dtb" /soc@0/iommu@3da0000 dma-coherent
cd "$dest"
sha256sum Image board.dtb initramfs.cpio.gz
tar -czf r183-payload.tar.gz Image board.dtb initramfs.cpio.gz
