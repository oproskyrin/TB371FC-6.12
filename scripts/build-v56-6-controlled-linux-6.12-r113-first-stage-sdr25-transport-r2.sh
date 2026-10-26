#!/usr/bin/env bash
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
v565=/mnt/d/TB371FC-builds/arch-development-loader-v56-5-r2-community-simplefb-qca6390-kde-kexec-cpu-hotplug-safe
stock="$project/artifacts/device-backup/lun0-recovery_b.bin"
kernel=/root/tb371fc-desktop-v56-6-watchdog-kexec-release/Image
base=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-v56.6-controlled-kexec-r108-transport-r2
base_ramdisk=$base/tb371fc-v56.6-controlled-linux-6.12-r108-transport-r2.cpio.gz
first_stage=/mnt/d/TB371FC-builds/arch-development-loader-v56-5-r113-first-stage-sdr25-dtb/dtb-v56-5-r113-first-stage-sdr25.img
out=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-v56.6-controlled-kexec-r113-first-stage-sdr25-transport-r2
ramdisk=$out/tb371fc-v56.6-controlled-linux-6.12-r113-first-stage-sdr25-transport-r2.cpio.gz
recovery=$out/tb371fc-v56.6-controlled-linux-6.12-r113-first-stage-sdr25-transport-r2-recovery.img

if ! test -s "$base_ramdisk"; then
  bash "$project/scripts/build-v56-6-controlled-linux-6.12-r108-microsd-redriver-hog-poll-transport-r2.sh"
fi
bash "$project/scripts/build-v56-5-r113-first-stage-sdr25-dtb.sh"
for input in "$stock" "$kernel" "$base_ramdisk" "$first_stage" "$v565/recovery-dtbo-v56-5.img"; do
  test -s "$input"
done
mkdir -p "$out"
test ! -e "$recovery"
cp --reflink=auto "$base_ramdisk" "$ramdisk"

# Keep the exact r108 second-stage payload and diagnostics. Only the outgoing
# 4.19 base DTB changes: it is forced to SDR12/SDR25 so it should leave the card
# and SD I/O rail in the 3.3-V state expected by r108's no-1-8-v consumer.
RECOVERY_DTBO="$v565/recovery-dtbo-v56-5.img" \
DIAGNOSTIC_CMDLINE='earlycon=qcom_geni,0x988000 console=ttyMSM0,115200n8 console=tty0 keep_bootcon ignore_loglevel rdinit=/init root=/dev/ram0 rw fw_devlink=permissive clk_ignore_unused pd_ignore_unused regulator_ignore_unused panic=-1 swiotlb=2048 msm_drm.sdecustom=0 video=Virtual-1:d fbcon=font:SUN12x22 fbcon=nodefer' \
  bash "$project/scripts/build-diagnostic-recovery.sh" \
    /root/mkbootimg/mkbootimg.py /root/mkbootimg/unpack_bootimg.py \
    /root/avb/avbtool.py "$stock" "$kernel" "$ramdisk" "$first_stage" "$recovery"

cat >"$out/BUILD-INFO.txt" <<'EOF'
R113 first-stage SDR25 electrical-alignment transport.

The complete r108 Linux 6.12 payload is retained byte-for-byte: r70 Image,
r108 PIO/no-IOMMU/no-1-8-v second-stage DTB, r108 diagnostics, GPIO75 hog,
UFS disabled, USB1 disabled, and no Android mounts.

Only the outgoing Lenovo 4.19 base DTB changes. qcom,bus-speed-mode on
/soc/sdhci@8804000 is limited to SDR12 and SDR25 in every real concatenated
base-DTB entry. The recovery DTBO is unchanged and does not contain an SDHCI
speed override. This tests whether a 3.3-V/legacy-speed kexec handoff lets the
6.12 host enumerate the card without a working RPMh/vqmmc provider.
EOF
sha256sum "$kernel" "$ramdisk" "$first_stage" \
  "$v565/recovery-dtbo-v56-5.img" "$recovery" >"$out/SHA256SUMS"
cat "$out/SHA256SUMS"
