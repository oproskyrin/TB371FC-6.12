#!/bin/sh
# R163: QCA6390 Wi-Fi at boot (R159 kernel modules), join the configured network, DHCP. RAM only.
set -u
exec >>/run/r163-wifi.log 2>&1
root=/run/r163-modroot
for i in $(seq 1 60); do [ -f $root/lib/modules/$(uname -r)/modules.dep ] && break; sleep 1; done
old=$(cat /sys/class/firmware/timeout 2>/dev/null || echo 60)
echo 1 >/sys/class/firmware/timeout 2>/dev/null || true
for k in michael_mic pwrseq-core pwrseq-qcom-wcn cfg80211 mac80211 ath qmi_helpers \
         ath11k ath11k_pci pci-pwrctrl-core pci-pwrctrl-pwrseq phy-qcom-qmp-pcie; do
	timeout 60 modprobe -d $root $k || echo "R163 wifi: modprobe $k rc=$?"
done
# Cold boot: PCIe link training runs before pwrctrl powers the QCA6390, so the bridge window is
# not sized at first. R172 boots with pci=realloc, which assigns the BAR once the chip appears.
# Never remove the endpoint here: pwrctrl then powers the chip (and Bluetooth) off for good.
for i in $(seq 1 60); do [ -e /sys/class/net/wlp1s0 ] && break; sleep 1; done
echo "$old" >/sys/class/firmware/timeout 2>/dev/null || true
[ -e /sys/class/net/wlp1s0 ] || { echo 'R163 wifi: no wlp1s0'; exit 0; }
ip link set wlp1s0 up
# R167: NetworkManager owns Wi-Fi (KDE network applet); the home network is pre-provisioned.
sh /run/r130/config/r166-nm.sh
echo "R163 wifi: started (NetworkManager) uptime=$(cut -d' ' -f1 /proc/uptime)"
