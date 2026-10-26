#!/usr/bin/env bash
set -euo pipefail
project="$(cd "$(dirname "$0")/.." && pwd)"
pkg=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r118-pinctrl
out=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-v56.6-controlled-kexec-r118-transport-r2
v565=/mnt/d/TB371FC-builds/arch-development-loader-v56-5-r2-community-simplefb-qca6390-kde-kexec-cpu-hotplug-safe
recovery=$out/tb371fc-v56.6-controlled-linux-6.12-r118-transport-r2-recovery.img
ramdisk=$out/tb371fc-v56.6-controlled-linux-6.12-r118-transport-r2.cpio.gz
export RECOVERY_DTBO="$v565/recovery-dtbo-v56-5.img"
bash "$project/scripts/verify-diagnostic-recovery.sh" /root/mkbootimg/unpack_bootimg.py /root/avb/avbtool.py \
 "$recovery" "$project/artifacts/device-backup/lun0-recovery_b.bin" \
 /root/tb371fc-desktop-v56-6-watchdog-kexec-release/Image "$ramdisk" "$v565/dtb-v56-5.img" \
 "$(sha256sum "$recovery" | awk '{print $1}')"
stage=$(mktemp -d /tmp/tb371fc-r118-audit-XXXXXX)
inner=$(mktemp -d /tmp/tb371fc-r118-inner-XXXXXX)
# Keep extraction directories for review; no recursive cleanup of unknown paths.
gzip -dc "$ramdisk" | (cd "$stage"; cpio -idmu 2>/dev/null)
for pair in Image:Image board.dtb:board.dtb initramfs.cpio.gz:initramfs.cpio.gz; do
 cmp "$stage/opt/tb371fc-linux-6.12-r38/${pair%%:*}" "$pkg/${pair#*:}"
done
gzip -dc "$pkg/initramfs.cpio.gz" | (cd "$inner"; cpio -idmu 2>/dev/null)
for script in "$stage/bin/load-linux-6.12-r38" "$inner/bin/boot-arch-development-rootfs"; do sh -n "$script"; done
for name in Image board.dtb initramfs.cpio.gz; do
 grep -Fq "$(sha256sum "$pkg/$name" | awk '{print $1}')" "$stage/bin/load-linux-6.12-r38"
done
grep -qx CONFIG_PINCTRL_MSM=y "$pkg/.config"
grep -qx CONFIG_PINCTRL_SM8250=y "$pkg/.config"
grep -q ' sm8250_pinctrl_probe$' "$pkg/System.map"
grep -q ' tb371fc_early_pgtable_pool$' "$pkg/System.map"
grep -Fq 'systemd.unit=multi-user.target' "$stage/bin/load-linux-6.12-r38"
grep -Fq 'exec switch_root "$new_root" /sbin/init' "$inner/bin/boot-arch-development-rootfs"
! grep -q 'devmem' "$inner/bin/boot-arch-development-rootfs"
test "$(fdtget -t s "$pkg/board.dtb" /soc/mmc@8804000 pinctrl-names)" = 'default sleep'
test "$(fdtget -t x "$pkg/board.dtb" /soc/mmc@8804000 pinctrl-0)" = bf
for node in /soc/ufshc@1d84000 /soc/usb@a6f8800; do
 test "$(fdtget -t s "$pkg/board.dtb" "$node" status)" = disabled
done
xo=/clocks/tb371fc-inherited-cxo-div2
test "$(fdtget -t i "$pkg/board.dtb" "$xo" clock-div)" = 2
test "$(fdtget -t i "$pkg/board.dtb" /clocks/xo-board clock-frequency)" = 38400000
ph=$(fdtget -t x "$pkg/board.dtb" "$xo" phandle)
test "$(fdtget -t x "$pkg/board.dtb" /soc/clock-controller@100000 clocks)" = "$ph $ph 2f"
printf 'PACKAGING_AND_STATIC_CHECKS=PASS\nHARDWARE_BOOT=NOT_TESTED\n'
sha256sum "$recovery" "$pkg/Image" "$pkg/board.dtb" "$pkg/initramfs.cpio.gz"
