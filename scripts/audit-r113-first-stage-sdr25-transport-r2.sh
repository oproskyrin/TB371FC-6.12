#!/usr/bin/env bash
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
v565=/mnt/d/TB371FC-builds/arch-development-loader-v56-5-r2-community-simplefb-qca6390-kde-kexec-cpu-hotplug-safe
base=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-v56.6-controlled-kexec-r108-transport-r2
out=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-v56.6-controlled-kexec-r113-first-stage-sdr25-transport-r2
recovery=$out/tb371fc-v56.6-controlled-linux-6.12-r113-first-stage-sdr25-transport-r2-recovery.img
ramdisk=$out/tb371fc-v56.6-controlled-linux-6.12-r113-first-stage-sdr25-transport-r2.cpio.gz
base_ramdisk=$base/tb371fc-v56.6-controlled-linux-6.12-r108-transport-r2.cpio.gz
first_stage=/mnt/d/TB371FC-builds/arch-development-loader-v56-5-r113-first-stage-sdr25-dtb/dtb-v56-5-r113-first-stage-sdr25.img
expected_dtb=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r108-headless-microsd-redriver-hog-poll-dtb/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram-ufs-disabled-no-usb1-mmc-no-iommu-pio-redriver-hog-poll.dtb
expected_image=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r70-embedded-pgtable-pool/Image
stage=$(mktemp -d)
outer=$(mktemp -d)
trap 'rm -rf -- "$stage" "$outer"' EXIT

cmp "$ramdisk" "$base_ramdisk"
python3 "$project/scripts/extract-concatenated-dtb.py" "$first_stage" "$outer" >/dev/null
for index in 00 01 02; do
  test "$(fdtget -t s "$outer/entry-$index.dtb" /soc/sdhci@8804000 qcom,bus-speed-mode)" = \
    'SDR12 SDR25'
done
export RECOVERY_DTBO="$v565/recovery-dtbo-v56-5.img"
expected_sha=$(sha256sum "$recovery" | awk '{print $1}')
bash "$project/scripts/verify-diagnostic-recovery.sh" \
  /root/mkbootimg/unpack_bootimg.py /root/avb/avbtool.py "$recovery" \
  "$project/artifacts/device-backup/lun0-recovery_b.bin" \
  /root/tb371fc-desktop-v56-6-watchdog-kexec-release/Image "$ramdisk" \
  "$first_stage" "$expected_sha"
gzip -dc "$ramdisk" | ( cd "$stage"; cpio -idmu 2>/dev/null )
cmp "$stage/opt/tb371fc-linux-6.12-r38/Image" "$expected_image"
cmp "$stage/opt/tb371fc-linux-6.12-r38/board.dtb" "$expected_dtb"
grep -Fq 'R108 SDHCI DIAGNOSTICS BEGIN' \
  <(gzip -dc "$stage/opt/tb371fc-linux-6.12-r38/initramfs.cpio.gz" | strings)
grep -Fq 'no-1-8-v' <(fdtdump "$expected_dtb" 2>/dev/null)
test "$(fdtget -t x "$expected_dtb" /soc/mmc@8804000 max-frequency)" = 17d7840
echo "RECOVERY_SHA256=$expected_sha"
echo 'AUDIT_RESULT=PASS'
