#!/usr/bin/env bash
set -euo pipefail
project="$(cd "$(dirname "$0")/.." && pwd)"
v565=/mnt/d/TB371FC-builds/arch-development-loader-v56-5-r2-community-simplefb-qca6390-kde-kexec-cpu-hotplug-safe
out=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-v56.6-controlled-kexec-r58-transport-r2
export RECOVERY_DTBO="$v565/recovery-dtbo-v56-5.img"
bash "$project/scripts/verify-diagnostic-recovery.sh" \
  /root/mkbootimg/unpack_bootimg.py \
  /root/avb/avbtool.py \
  "$out/tb371fc-v56.6-controlled-linux-6.12-r58-transport-r2-recovery.img" \
  "$project/artifacts/device-backup/lun0-recovery_b.bin" \
  /root/tb371fc-desktop-v56-6-watchdog-kexec-release/Image \
  "$out/tb371fc-v56.6-controlled-linux-6.12-r58-transport-r2.cpio.gz" \
  "$v565/dtb-v56-5.img" \
  f914042eacccc3efae5040651976b114b121f58f6a6131265d19d32673697087
echo "AUDIT_RESULT=PASS"
