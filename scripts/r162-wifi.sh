#!/bin/sh
# R162: QCA6390 Wi-Fi on the R159 kernel (modules from /run/r159-modroot), join the configured
# network (/run/r162-wpa.conf, PSK hash only), DHCP. RAM only. Based on R152.
set -u
root=/run/r159-modroot; kr=$(uname -r)
old=$(cat /sys/class/firmware/timeout 2>/dev/null || echo 60)
echo 1 >/sys/class/firmware/timeout 2>/dev/null || true
for k in michael_mic pwrseq-core pwrseq-qcom-wcn cfg80211 mac80211 ath qmi_helpers \
         ath11k ath11k_pci pci-pwrctrl-core pci-pwrctrl-pwrseq phy-qcom-qmp-pcie; do
	timeout 60 modprobe -d $root $k || echo "modprobe $k rc=$?"
done
for i in $(seq 1 90); do [ -e /sys/class/net/wlp1s0 ] && break; sleep 1; done
echo "$old" >/sys/class/firmware/timeout 2>/dev/null || true
[ -e /sys/class/net/wlp1s0 ] || { echo 'no wlp1s0'; dmesg | grep -i -E "ath11k|pcie|pwrseq" | tail -15; exit 1; }
ip link set wlp1s0 up
wpa_supplicant -B -D nl80211 -i wlp1s0 -c /run/r162-wpa.conf -f /run/r162-wpa.log
dhcpcd -4 -b wlp1s0 >/dev/null 2>&1
ip4=
for i in $(seq 1 60); do ip4=$(ip -4 -o addr show wlp1s0 | awk '{print $4}' | cut -d/ -f1); [ -n "$ip4" ] && break; sleep 1; done
echo "wifi ip=$ip4"
iw dev wlp1s0 link 2>/dev/null | grep -E "SSID|freq|signal|tx bitrate" | sed 's/SSID.*/SSID: (hidden in log)/'
ping -c 2 -W 3 archlinuxarm.org 2>&1 | tail -2
