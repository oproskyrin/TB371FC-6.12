#!/usr/bin/env bash
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
v565=/mnt/d/TB371FC-builds/arch-development-loader-v56-5-r2-community-simplefb-qca6390-kde-kexec-cpu-hotplug-safe
out=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-v56.6-controlled-kexec-r84-transport-r2
recovery=$out/tb371fc-v56.6-controlled-linux-6.12-r84-transport-r2-recovery.img
ramdisk=$out/tb371fc-v56.6-controlled-linux-6.12-r84-transport-r2.cpio.gz
expected_image=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r83-dt-allocator-success-checkpoint/Image
expected_dtb=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r84-real-ram-map-dtb/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram.dtb
unpacked=$(mktemp -d)
stage=$(mktemp -d)
trap 'rm -rf -- "$unpacked" "$stage"' EXIT

export RECOVERY_DTBO="$v565/recovery-dtbo-v56-5.img"
expected_sha=$(sha256sum "$recovery" | awk '{print $1}')
bash "$project/scripts/verify-diagnostic-recovery.sh" \
  /root/mkbootimg/unpack_bootimg.py \
  /root/avb/avbtool.py \
  "$recovery" \
  "$project/artifacts/device-backup/lun0-recovery_b.bin" \
  /root/tb371fc-desktop-v56-6-watchdog-kexec-release/Image \
  "$ramdisk" \
  "$v565/dtb-v56-5.img" \
  "$expected_sha"

gzip -dc "$ramdisk" | ( cd "$stage"; cpio -idmu 2>/dev/null )
cmp "$stage/opt/tb371fc-linux-6.12-r38/Image" "$expected_image"
cmp "$stage/opt/tb371fc-linux-6.12-r38/board.dtb" "$expected_dtb"
test "$(fdtget -t x "$stage/opt/tb371fc-linux-6.12-r38/board.dtb" /memory@80000000 reg | wc -w)" = 76
grep -Fq "$(sha256sum "$expected_image" | awk '{print $1}')" "$stage/bin/load-linux-6.12-r38"
grep -Fq "$(sha256sum "$expected_dtb" | awk '{print $1}')" "$stage/bin/load-linux-6.12-r38"
echo "AUDIT_RESULT=PASS"

