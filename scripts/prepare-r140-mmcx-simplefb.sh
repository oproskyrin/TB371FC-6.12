#!/usr/bin/env bash
# R140: exact R131 Image/initramfs/DT plus two properties on the boot
# framebuffer node, so simpledrm keeps the RPMh MMCX domain at NOM after
# rpmhpd_sync_state(). Hypothesis: sync_state votes 0 for MMCX (fw_devlink=off
# makes it run right after probe) and the continuous-splash scanout dies.
set -euo pipefail
base=/mnt/d/TB371FC-builds/checkpoints/r131-arch612-rpmh-usb-20261024
pkg=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r140-mmcx-simplefb
fb=/chosen/framebuffer@9c000000
test ! -e "$pkg"
mkdir "$pkg"
printf '%s  %s\n' 7c11303edcd7a0b8b21389a5065f8048f36d81cefe358a6f5f9297edc76a9aab "$base/board.dtb" | sha256sum -c -
printf '%s  %s\n' 03b2f15272040962984d70f77356b9686429f0b7024d85ed8fa4150b6129ec61 "$base/Image" | sha256sum -c -
printf '%s  %s\n' cb68f76732b8c21c6ca8dfec7ca886c006082210fde78ede4da552d2fbcbaa70 "$base/initramfs.cpio.gz" | sha256sum -c -
cp "$base/Image" "$base/initramfs.cpio.gz" "$base/board.dtb" "$pkg/"
d="$pkg/board.dtb"
# Verify the phandles this patch relies on before writing them.
pc=$(fdtget -t x "$d" /soc/rsc@18200000/power-controller phandle)
test "$pc" = 34
test "$(fdtget -t s "$d" /soc/rsc@18200000/power-controller compatible)" = qcom,sm8250-rpmhpd
opp=/soc/rsc@18200000/power-controller/opp-table/opp6
test "$(fdtget -t x "$d" "$opp" phandle)" = 6b
test "$(fdtget -t x "$d" "$opp" opp-level)" = 100   # RPMH_REGULATOR_LEVEL_NOM
test "$(fdtget -t x "$d" /soc/clock-controller@af00000 power-domains)" = "34 6"  # dispcc uses MMCX=6
test "$(fdtget -t s "$d" "$fb" compatible)" = simple-framebuffer
! fdtget "$d" "$fb" power-domains 2>/dev/null
! fdtget "$d" "$fb" required-opps 2>/dev/null
fdtput -t x "$d" "$fb" power-domains 34 6
fdtput -t x "$d" "$fb" required-opps 6b
dtc -q -s -I dtb -O dts "$base/board.dtb" > "$pkg/base-r131.dts"
dtc -q -s -I dtb -O dts "$d" > "$pkg/candidate.dts"
diff -u "$pkg/base-r131.dts" "$pkg/candidate.dts" > "$pkg/dtb.diff" || test "$?" = 1
# Roundtrip: removing the two properties must give back the exact R131 DT.
cp "$d" "$pkg/roundtrip.dtb"
fdtput -d "$pkg/roundtrip.dtb" "$fb" power-domains
fdtput -d "$pkg/roundtrip.dtb" "$fb" required-opps
dtc -q -s -I dtb -O dts "$pkg/roundtrip.dtb" > "$pkg/roundtrip.dts"
cmp "$pkg/base-r131.dts" "$pkg/roundtrip.dts"
rm "$pkg/roundtrip.dtb" "$pkg/roundtrip.dts"
cmp "$pkg/Image" "$base/Image"
cmp "$pkg/initramfs.cpio.gz" "$base/initramfs.cpio.gz"
cd "$pkg"
sha256sum Image board.dtb initramfs.cpio.gz > SHA256SUMS
tar -czf r140-payload.tar.gz Image board.dtb initramfs.cpio.gz
sha256sum r140-payload.tar.gz >> SHA256SUMS
cat SHA256SUMS
cat dtb.diff
