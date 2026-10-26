#!/usr/bin/env bash
# R165 DT: R164 DT with operating-points-v2 also removed from the CPU nodes. The DT OPP tables
# carry opp-peak-kBps for the (removed) CPU interconnect paths, so the OPP core rejected them
# ("_read_bw: Mismatch between opp-peak-kBps and paths (2 0)") and cpufreq-hw failed to read the
# LUT. Without a DT OPP table qcom-cpufreq-hw uses the EPSS hardware LUT directly.
set -euo pipefail
base=/mnt/d/TB371FC-builds/r164-thermal/board.dtb
pkg=/mnt/d/TB371FC-builds/r165-cpufreq; mkdir -p "$pkg"
test "$(sha256sum "$base" | cut -d' ' -f1)" = 49c42b852bdb93e6e001248fce82290dcf19f9f67cbdc1a828ec2b58eecdc680
cp "$base" "$pkg/board.dtb"
cpus=$(fdtget -l "$pkg/board.dtb" /cpus | grep "^cpu@"); test "$(echo $cpus | wc -w)" = 8
for c in $cpus; do fdtput -d "$pkg/board.dtb" /cpus/$c operating-points-v2; done
dtc -q -s -I dtb -O dts "$base" > "$pkg/baseline-r164.dts"
dtc -q -s -I dtb -O dts "$pkg/board.dtb" > "$pkg/candidate.dts"
diff -u "$pkg/baseline-r164.dts" "$pkg/candidate.dts" > "$pkg/dtb.diff" || test "$?" = 1
grep -c '^-.*operating-points-v2' "$pkg/dtb.diff"; grep -c '^[-+][^-+]' "$pkg/dtb.diff"
a=/mnt/d/TB371FC-builds/r164-autoboot
(cd "$a"; grep -E " (Image|initramfs.cpio.gz)$" SHA256SUMS | sha256sum -c -)
cp "$a/Image" "$a/initramfs.cpio.gz" "$pkg/"
cd "$pkg"; sha256sum Image board.dtb initramfs.cpio.gz > SHA256SUMS
tar -czf r165-payload.tar.gz Image board.dtb initramfs.cpio.gz; sha256sum r165-payload.tar.gz >> SHA256SUMS; cat SHA256SUMS
