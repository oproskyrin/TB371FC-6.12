#!/usr/bin/env bash
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
v565=/mnt/d/TB371FC-builds/arch-development-loader-v56-5-r2-community-simplefb-qca6390-kde-kexec-cpu-hotplug-safe
out=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-v56.6-controlled-kexec-r115-transport-r2
recovery=$out/tb371fc-v56.6-controlled-linux-6.12-r115-transport-r2-recovery.img
ramdisk=$out/tb371fc-v56.6-controlled-linux-6.12-r115-transport-r2.cpio.gz
expected_image=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r70-embedded-pgtable-pool/Image
expected_dtb=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r115-microsd-redriver-pwrseq-dtb/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram-ufs-disabled-no-usb1-mmc-no-iommu-pio-redriver-pwrseq.dtb
stage=$(mktemp -d)
inner=$(mktemp -d)
trap 'rm -rf -- "$stage" "$inner"' EXIT

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
gzip -dc "$stage/opt/tb371fc-linux-6.12-r38/initramfs.cpio.gz" | \
  ( cd "$inner"; cpio -idmu 2>/dev/null )
sh -n "$inner/bin/boot-arch-development-rootfs"
grep -Fq 'R115 SDHCI DIAGNOSTICS BEGIN' "$inner/bin/boot-arch-development-rootfs"
test "$(fdtget -t s "$expected_dtb" /sd-redriver-pwrseq compatible)" = mmc-pwrseq-simple
test "$(fdtget -t x "$expected_dtb" /sd-redriver-pwrseq reset-gpios)" = '3b 4b 1'
test "$(fdtget -t x "$expected_dtb" /soc/mmc@8804000 mmc-pwrseq)" = 121
! fdtget "$expected_dtb" /soc/pinctrl@f100000/sd-redriver-hog gpio-hog >/dev/null 2>&1
test "$(grep -o 'fw_devlink=off' "$stage/bin/load-linux-6.12-r38" | wc -l)" = 1
test "$(fdtget -t s "$expected_dtb" /soc/ufshc@1d84000 status)" = disabled
test "$(fdtget -t s "$expected_dtb" /soc/usb@a6f8800 status)" = disabled
echo "RECOVERY_SHA256=$expected_sha"
echo 'AUDIT_RESULT=PASS'
