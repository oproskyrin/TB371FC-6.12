#!/usr/bin/env bash
# R159: new kernel = R130 config + remoteproc/ADSP (QCOM_Q6V5_PAS), sysmon, RPMh
# regulators and QMP PCIe PHY as in-tree modules, and lockup/hung-task detectors.
# Same donor source as R130 (linux-6.12-donor-r118); separate output dir.
set -euo pipefail
src=/root/tb371fc/linux-6.12-donor-r118
base=/root/tb371fc/build-6.12-r130-usb2-late
out=/root/tb371fc/build-6.12-r159-audio
pkg=/mnt/d/TB371FC-builds/r159-audio
if [ "${1:-}" != --resume ]; then
    test ! -e "$out"; test ! -e "$pkg"
    mkdir -p "$out" "$pkg"
    cp "$base/.config" "$out/.config"
    c() { "$src/scripts/config" --file "$out/.config" "$@"; }
    c --set-str LOCALVERSION '-tb371fc-r159-audio'
    c --enable REMOTEPROC --disable REMOTEPROC_CDEV
    c --module QCOM_RPROC_COMMON --module QCOM_Q6V5_COMMON --module QCOM_Q6V5_PAS
    c --module QCOM_SYSMON --module QCOM_PIL_INFO
    c --module REGULATOR_QCOM_RPMH
    c --enable PHY_QCOM_QMP --module PHY_QCOM_QMP_PCIE
    c --enable SOFTLOCKUP_DETECTOR --enable DETECT_HUNG_TASK --set-val DEFAULT_HUNG_TASK_TIMEOUT 120
    make -C "$src" O="$out" ARCH=arm64 LLVM=-18 olddefconfig > "$pkg/olddefconfig.log" 2>&1
fi
grep -E "^CONFIG_(REMOTEPROC|QCOM_Q6V5_PAS|QCOM_Q6V5_COMMON|QCOM_SYSMON|QCOM_RPROC_COMMON|QCOM_PIL_INFO|REGULATOR_QCOM_RPMH|PHY_QCOM_QMP_PCIE|SOFTLOCKUP_DETECTOR|DETECT_HUNG_TASK|LOCALVERSION)=" "$out/.config" | tee "$pkg/config-delta.txt"
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 -j8 Image modules > "$pkg/build.log" 2>&1 || { tail -30 "$pkg/build.log"; exit 1; }
cp "$out/arch/arm64/boot/Image" "$pkg/Image"
cp "$out/.config" "$pkg/config"
rm -rf "$pkg/modroot"
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 INSTALL_MOD_PATH="$pkg/modroot" INSTALL_MOD_STRIP=1 modules_install > "$pkg/modules_install.log" 2>&1
kr=$(cat "$out/include/config/kernel.release"); echo "kernel.release=$kr" | tee -a "$pkg/config-delta.txt"
du -sh "$pkg/modroot"
sha256sum "$pkg/Image"
