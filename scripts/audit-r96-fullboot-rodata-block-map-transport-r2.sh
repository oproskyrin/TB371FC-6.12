#!/usr/bin/env bash
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
v565=/mnt/d/TB371FC-builds/arch-development-loader-v56-5-r2-community-simplefb-qca6390-kde-kexec-cpu-hotplug-safe
out=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-v56.6-controlled-kexec-r96-transport-r2
recovery=$out/tb371fc-v56.6-controlled-linux-6.12-r96-transport-r2-recovery.img
ramdisk=$out/tb371fc-v56.6-controlled-linux-6.12-r96-transport-r2.cpio.gz
expected_image=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r70-embedded-pgtable-pool/Image
expected_dtb=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r84-real-ram-map-dtb/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram.dtb
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
test "$(sha256sum "$expected_dtb" | awk '{print $1}')" = c954a4d36e5bf25c2884bc83293222fd866697556c2fa2fc9f67dbcd85fbfcae
test "$(fdtget -t x "$stage/opt/tb371fc-linux-6.12-r38/board.dtb" /memory@80000000 reg | wc -w)" = 76
grep -Fq 'reset_devices rodata=on' "$stage/bin/load-linux-6.12-r38"
test "$(grep -o 'rodata=on' "$stage/bin/load-linux-6.12-r38" | wc -l)" = 1
! grep -Fq 'rodata=full' "$stage/bin/load-linux-6.12-r38"
grep -Fq '9644d29f837f0d52f7b25dcc19a4ea6b495833782810f2e6a933d74dacfd662f' "$stage/bin/load-linux-6.12-r38"
grep -Fq 'c954a4d36e5bf25c2884bc83293222fd866697556c2fa2fc9f67dbcd85fbfcae' "$stage/bin/load-linux-6.12-r38"
sh -n "$stage/bin/load-linux-6.12-r38"
echo "AUDIT_RESULT=PASS"
