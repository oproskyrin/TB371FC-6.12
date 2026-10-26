#!/bin/bash
# R185 DTB: R184 (battery) + R179 headless GPU (MDSS disabled, tb371fc,headless-gpu) + GPU SMMU
# without "qcom,adreno-smmu" (global GPU page table: R183's per-process tables faulted on every IB).
set -euo pipefail
base=/mnt/d/TB371FC-builds/r184-autoboot; g=/mnt/d/TB371FC-builds/r179-autoboot
dest=/mnt/d/TB371FC-builds/r185-autoboot; rm -rf "$dest"; mkdir -p "$dest"
test "$(sha256sum "$base/board.dtb" | cut -d' ' -f1)" = 33eaf41be0dda8c77f5c465a7e521aeade1dd9830563bade7535c49f5689f1b4
cp "$g/Image" "$g/initramfs.cpio.gz" "$dest/"; cp "$base/board.dtb" "$dest/board.dtb"; d=$dest/board.dtb
fdtput -t s "$d" /soc@0/display-subsystem@ae00000 status disabled
fdtput -t bx "$d" /soc@0/gpu@3d00000 tb371fc,headless-gpu 00
fdtput -t s "$d" /soc@0/iommu@3da0000 compatible qcom,sm8250-smmu-500 qcom,smmu-500 arm,mmu-500
# the only differences to R179 must be the battery changes
dtc -q -s -I dtb -O dts "$g/board.dtb" > /tmp/r179.dts; dtc -q -s -I dtb -O dts "$d" > /tmp/r185.dts
diff /tmp/r179.dts /tmp/r185.dts || true
cd "$dest"; sha256sum Image board.dtb initramfs.cpio.gz | tee SHA256SUMS
tar -czf r185-payload.tar.gz Image board.dtb initramfs.cpio.gz
