#!/usr/bin/env bash
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
v565=/mnt/d/TB371FC-builds/arch-development-loader-v56-5-r2-community-simplefb-qca6390-kde-kexec-cpu-hotplug-safe
out=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-v56.6-controlled-kexec-r105-transport-r2
recovery=$out/tb371fc-v56.6-controlled-linux-6.12-r105-transport-r2-recovery.img
ramdisk=$out/tb371fc-v56.6-controlled-linux-6.12-r105-transport-r2.cpio.gz
expected_image=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r70-embedded-pgtable-pool/Image
expected_dtb=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r105-headless-microsd-no-iommu-pio-dtb/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram-ufs-disabled-no-usb1-mmc-no-iommu-pio.dtb
expected_inner=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r105-sdhci-diagnostic-initramfs/initramfs-6.12-r105-sdhci-diagnostics.cpio.gz
stage=$(mktemp -d)
inner_stage=$(mktemp -d)
trap 'rm -rf -- "$stage" "$inner_stage"' EXIT

export RECOVERY_DTBO="$v565/recovery-dtbo-v56-5.img"
expected_sha=$(sha256sum "$recovery" | awk '{print $1}')
bash "$project/scripts/verify-diagnostic-recovery.sh" \
  /root/mkbootimg/unpack_bootimg.py /root/avb/avbtool.py "$recovery" \
  "$project/artifacts/device-backup/lun0-recovery_b.bin" \
  /root/tb371fc-desktop-v56-6-watchdog-kexec-release/Image "$ramdisk" \
  "$v565/dtb-v56-5.img" "$expected_sha"

gzip -dc "$ramdisk" | ( cd "$stage"; cpio -idmu 2>/dev/null )
cmp "$stage/opt/tb371fc-linux-6.12-r38/Image" "$expected_image"
cmp "$stage/opt/tb371fc-linux-6.12-r38/board.dtb" "$expected_dtb"
cmp "$stage/opt/tb371fc-linux-6.12-r38/initramfs.cpio.gz" "$expected_inner"
inner_sha=$(sha256sum "$expected_inner" | awk '{print $1}')
gzip -dc "$expected_inner" | ( cd "$inner_stage"; cpio -idmu 2>/dev/null )
diag="$inner_stage/bin/boot-arch-development-rootfs"
grep -Fq 'R105 SDHCI DIAGNOSTICS BEGIN' "$diag"
grep -Fq 'busybox tail -n 160' "$diag"
sh -n "$diag"
helper="$stage/bin/load-linux-6.12-r38"
test "$(grep -o 'fw_devlink=off' "$helper" | wc -l)" = 1
! grep -Fq 'fw_devlink=permissive' "$helper"
grep -Fq "$inner_sha" "$helper"
! fdtget "$expected_dtb" /soc/mmc@8804000 iommus >/dev/null 2>&1
test "$(fdtget -t x "$expected_dtb" /soc/mmc@8804000 sdhci-caps-mask)" = "0 480000"
test "$(fdtget -t s "$expected_dtb" /soc/ufshc@1d84000 status)" = disabled
test "$(fdtget -t s "$expected_dtb" /soc/usb@a6f8800 status)" = disabled
echo "INNER_INITRAMFS_SHA256=$inner_sha"
echo "RECOVERY_SHA256=$expected_sha"
echo "AUDIT_RESULT=PASS"
