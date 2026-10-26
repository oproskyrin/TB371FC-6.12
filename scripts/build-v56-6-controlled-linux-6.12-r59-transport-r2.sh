#!/usr/bin/env bash
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
v565=/mnt/d/TB371FC-builds/arch-development-loader-v56-5-r2-community-simplefb-qca6390-kde-kexec-cpu-hotplug-safe
source_ramdisk=$v565/tb371fc-v56-5-r2-simplefb-qca6390-kde-kexec-cpu-hotplug-safe.cpio.gz
kernel=/root/tb371fc-desktop-v56-6-watchdog-kexec-release/Image
dtb=$v565/dtb-v56-5.img
recovery_dtbo=$v565/recovery-dtbo-v56-5.img
stock="$project/artifacts/device-backup/lun0-recovery_b.bin"
linux612=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r59-full-region-palette-indicator/Image
diag39='/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-arch612-diag39+-safe-diag39-r2'
linux612_dtb=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r57-boot-log-region-reserved-dtb/sm8250-lenovo-tb371fc-archsafe-microsd.dtb
linux612_initrd=$diag39/initramfs-6.12-arch-development.cpio.gz
output=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-v56.6-controlled-kexec-r59-transport-r2
ramdisk=$output/tb371fc-v56.6-controlled-linux-6.12-r59-transport-r2.cpio.gz
recovery=$output/tb371fc-v56.6-controlled-linux-6.12-r59-transport-r2-recovery.img

for f in "$source_ramdisk" "$kernel" "$dtb" "$recovery_dtbo" "$stock" "$linux612" "$linux612_dtb" "$linux612_initrd" \
	"$project/bin/tb371fc-development-init-runtime" \
	"$project/initramfs/init-v56-5-controlled-linux-6.12-r38" \
	"$project/initramfs/execute-linux-6.12-r38" \
	"$project/initramfs/status-linux-6.12-r38" \
	"$project/initramfs/load-linux-6.12-r40"; do test -s "$f"; done

image_sha=$(sha256sum "$linux612" | awk '{print $1}')
dtb_sha=$(sha256sum "$linux612_dtb" | awk '{print $1}')

printf '%s  %s\n' c807299d26b83c2d585a1ae8402dfbb68852a647ed153bf190123e9a7048dd9c "$linux612_initrd" | sha256sum -c -

mkdir -p "$output"
rm -f "$ramdisk" "$recovery"
stage=$(mktemp -d); unpacked=$(mktemp -d)
trap 'rm -rf -- "$stage" "$unpacked"' EXIT
( cd "$stage"; gzip -dc "$source_ramdisk" | cpio -idmu 2>/dev/null )
test -x "$stage/bin/kexec"
install -m0755 "$project/bin/tb371fc-development-init-runtime" "$stage/bin/tb371fc-development-init-runtime"
install -m0755 "$project/initramfs/init-v56-5-controlled-linux-6.12-r38" "$stage/init"
for h in execute status; do install -m0755 "$project/initramfs/${h}-linux-6.12-r38" "$stage/bin/${h}-linux-6.12-r38"; done
python3 - "$project/initramfs/load-linux-6.12-r40" "$stage/bin/load-linux-6.12-r38" "$image_sha" "$dtb_sha" <<'PYEOF'
import sys
src, dst, image_sha, dtb_sha = sys.argv[1:5]
text = open(src, encoding='utf-8').read()
text = text.replace(
	"39045f36e7f238139e2783b73b1b2a9f7874bcf476e6eb82119dbe1ae2e28680", image_sha)
text = text.replace(
	"caa9598e88b9b4a39d39916651d306824e2f44d8325822e510bcb6d0cede357c", dtb_sha)
text = text.replace("r40: Linux 6.12", "r59: Linux 6.12")
text = text.replace("r40: run", "r59: run")
open(dst, 'w', encoding='utf-8', newline='\n').write(text)
PYEOF
chmod 0755 "$stage/bin/load-linux-6.12-r38"
install -d -m0755 "$stage/opt/tb371fc-linux-6.12-r38"
install -m0644 "$linux612" "$stage/opt/tb371fc-linux-6.12-r38/Image"
install -m0644 "$linux612_dtb" "$stage/opt/tb371fc-linux-6.12-r38/board.dtb"
install -m0644 "$linux612_initrd" "$stage/opt/tb371fc-linux-6.12-r38/initramfs.cpio.gz"
for script in "$stage/init" "$stage/bin/tb371fc-development-init-runtime" "$stage/bin/"*-linux-6.12-r38; do sh -n "$script"; done
grep -Fq 'TB371FC_SERIAL_SSH_SESSION_TIMEOUT:-300' "$stage/bin/tb371fc-development-init-runtime"
grep -Fq '__TB371FC_SSH_STREAM_CLOSED__' "$stage/bin/tb371fc-development-init-runtime"
grep -Fq "$image_sha" "$stage/bin/load-linux-6.12-r38"
grep -Fq "$dtb_sha" "$stage/bin/load-linux-6.12-r38"
( cd "$stage"; find . -print0 | sort -z | cpio --null -o --format=newc --owner=0:0 2>/dev/null | gzip -9n >"$ramdisk" )

RECOVERY_DTBO="$recovery_dtbo" DIAGNOSTIC_CMDLINE='earlycon=qcom_geni,0x988000 console=ttyMSM0,115200n8 console=tty0 keep_bootcon ignore_loglevel rdinit=/init root=/dev/ram0 rw fw_devlink=permissive clk_ignore_unused pd_ignore_unused regulator_ignore_unused panic=-1 swiotlb=2048 msm_drm.sdecustom=0 video=Virtual-1:d fbcon=font:SUN12x22 fbcon=nodefer' \
	bash "$project/scripts/build-diagnostic-recovery.sh" /root/mkbootimg/mkbootimg.py /root/mkbootimg/unpack_bootimg.py /root/avb/avbtool.py "$stock" "$kernel" "$ramdisk" "$dtb" "$recovery"
python3 /root/mkbootimg/unpack_bootimg.py --boot_img "$recovery" --out "$unpacked" --format=info >"$output/unpack-info.txt"
cmp "$unpacked/kernel" "$kernel"; cmp "$unpacked/ramdisk" "$ramdisk"; cmp "$unpacked/dtb" "$dtb"; cmp "$unpacked/recovery_dtbo" "$recovery_dtbo"
cat >"$output/BUILD-INFO.txt" <<EOF
TB371FC r59 controlled two-stage recovery, transport revision 2
First stage: V56.6 Linux 4.19 with local watchdog fallback and shutdown callback.
Linux 6.12 payload: r59, full-region palette exact-match indicator + r57's
DTB reserving boot_log_region unchanged.
Payload Image SHA-256: $image_sha
Payload DTB SHA-256: $dtb_sha
Temporary test touches only recovery_b and verification-disabled vbmeta_b.
EOF
( cd "$output"; sha256sum "$(basename "$ramdisk")" "$(basename "$recovery")" BUILD-INFO.txt >SHA256SUMS; sha256sum -c SHA256SUMS )
stat -c 'ramdisk=%s recovery=%s' "$ramdisk" "$recovery"
