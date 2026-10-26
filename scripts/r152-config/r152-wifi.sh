#!/bin/sh
# R152: bring up QCA6390 Wi-Fi (ath11k over PCIe0), join the configured network,
# DHCP, and a key-only sshd on the Wi-Fi address (port 2222). RAM only.
set -u
bb=/run/r130/busybox
m=/run/r130/modules
exec >>/run/r152-wifi.log 2>&1
echo "R152 wifi: start uptime=$(cut -d' ' -f1 /proc/uptime)"
# ath11k asks for an optional firmware-2.bin that is not shipped; do not wait 60 s for it.
old=$(cat /sys/class/firmware/timeout 2>/dev/null || echo 60)
echo 1 >/sys/class/firmware/timeout 2>/dev/null || true
for k in michael_mic pwrseq-core pwrseq-qcom-wcn cfg80211 mac80211 ath qmi_helpers \
         ath11k ath11k_pci pci-pwrctrl-core pci-pwrctrl-pwrseq phy-qcom-qmp-pcie; do
	"$bb" timeout 60 "$bb" insmod "$m/$k.ko" || echo "R152 wifi: insmod $k rc=$?"
done
for i in $("$bb" seq 1 90); do [ -e /sys/class/net/wlp1s0 ] && break; sleep 1; done
echo "$old" >/sys/class/firmware/timeout 2>/dev/null || true
[ -e /sys/class/net/wlp1s0 ] || { echo 'R152 wifi: no wlp1s0'; exit 1; }
ip link set wlp1s0 up
wpa_supplicant -B -D nl80211 -i wlp1s0 -c /run/r130/config/r152-wpa.conf -f /run/r152-wpa.log
dhcpcd -4 -b wlp1s0
ip4=
for i in $("$bb" seq 1 90); do
	ip4=$(ip -4 -o addr show wlp1s0 | awk '{print $4}' | cut -d/ -f1)
	[ -n "$ip4" ] && break
	sleep 1
done
echo "R152 wifi: ip=$ip4 uptime=$(cut -d' ' -f1 /proc/uptime)"
[ -n "$ip4" ] || exit 0
sed '/^ListenAddress/d' /etc/ssh/sshd_config.r130 >/run/sshd_config.wifi
printf 'ListenAddress %s\nPidFile /run/sshd-wifi.pid\n' "$ip4" >>/run/sshd_config.wifi
/usr/bin/sshd -t -f /run/sshd_config.wifi && /usr/bin/sshd -f /run/sshd_config.wifi -E /run/sshd-wifi.log
echo "R152 wifi: ssh on $ip4:2222"
