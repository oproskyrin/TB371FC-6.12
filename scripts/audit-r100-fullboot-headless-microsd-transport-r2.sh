#!/usr/bin/env bash
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
v565=/mnt/d/TB371FC-builds/arch-development-loader-v56-5-r2-community-simplefb-qca6390-kde-kexec-cpu-hotplug-safe
out=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-v56.6-controlled-kexec-r100-transport-r2
recovery=$out/tb371fc-v56.6-controlled-linux-6.12-r100-transport-r2-recovery.img
ramdisk=$out/tb371fc-v56.6-controlled-linux-6.12-r100-transport-r2.cpio.gz
expected_image=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r70-embedded-pgtable-pool/Image
expected_dtb=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r100-headless-microsd-no-rpmh-opp-dtb/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram-ufs-disabled-no-usb1-no-mmc-rpmh-opp.dtb
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT

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
test "$(sha256sum "$expected_image" | awk '{print $1}')" = 9644d29f837f0d52f7b25dcc19a4ea6b495833782810f2e6a933d74dacfd662f
! fdtget "$expected_dtb" /soc/mmc@8804000 power-domains >/dev/null 2>&1
! fdtget "$expected_dtb" /soc/mmc@8804000 operating-points-v2 >/dev/null 2>&1
test "$(fdtget -t x "$expected_dtb" /soc/mmc@8804000 max-frequency)" = 17d7840
test "$(fdtget -t x "$expected_dtb" /soc/mmc@8804000 bus-width)" = 4
test "$(fdtget -t s "$expected_dtb" /soc/ufshc@1d84000 status)" = disabled
test "$(fdtget -t s "$expected_dtb" /soc/phy@1d87000 status)" = disabled
test "$(fdtget -t s "$expected_dtb" /soc/usb@a6f8800 status)" = disabled
test "$(fdtget -t x "$expected_dtb" /memory@80000000 reg | wc -w)" = 76
grep -Fq "$(sha256sum "$expected_dtb" | awk '{print $1}')" "$stage/bin/load-linux-6.12-r38"
grep -Fq 'reset_devices rodata=on' "$stage/bin/load-linux-6.12-r38"
test "$(grep -o 'rodata=on' "$stage/bin/load-linux-6.12-r38" | wc -l)" = 1
! grep -Fq 'rodata=full' "$stage/bin/load-linux-6.12-r38"
sh -n "$stage/bin/load-linux-6.12-r38"
echo "AUDIT_RESULT=PASS"
