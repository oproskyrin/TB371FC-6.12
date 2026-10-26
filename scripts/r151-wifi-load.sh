#!/bin/sh
# R151: load Wi-Fi modules step by step from /run/r151-mods (RAM only).
set -u
m=/run/r151-mods
mkdir -p $m; tar -xzf /run/r151-modules.tar.gz -C $m
cat /proc/sys/kernel/random/boot_id
echo "== before"; ls /sys/bus/platform/devices | grep -E "1c00000|1c06000|qca6390" ; cat /sys/kernel/debug/devices_deferred 2>/dev/null | grep -E "1c0|qca"
step() { echo "R151 host: insmod $1" > /dev/kmsg; echo "== insmod $1"; timeout 40 insmod "$m/$1"; echo "rc=$?"; sleep 2; }
step pwrseq-core.ko
step pwrseq-qcom-wcn.ko
ls -l /sys/bus/platform/devices/qca6390-pmu/driver 2>&1
step cfg80211.ko
step mac80211.ko
step ath.ko
step qmi_helpers.ko
step ath11k.ko
step ath11k_pci.ko
step pci-pwrctrl-core.ko
step pci-pwrctrl-pwrseq.ko
step phy-qcom-qmp-pcie.ko
sleep 10
echo "== after"
ls /sys/bus/pci/devices/ 2>&1
lspci -nn 2>/dev/null
ip -br link
dmesg | grep -i -E "pcie|qcom-pcie|1c00000|1c06000|pwrseq|pwrctrl|ath11k|qca6390|mhi|wlan" | tail -40
