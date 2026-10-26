#!/bin/sh
# R166: hand Wi-Fi over to NetworkManager so KDE's network applet can pick networks.
# The USB gadget link (SSH) stays unmanaged. The preconfigured home network becomes an NM profile
# from the existing wpa config (raw 64-hex PSK only; nothing is printed).
set -u
exec >>/run/r166-nm.log 2>&1
src=/run/r130/config/r163-wpa.conf
mkdir -p /etc/NetworkManager/conf.d /etc/NetworkManager/system-connections
cat > /etc/NetworkManager/conf.d/50-tb371fc.conf <<'C'
[keyfile]
unmanaged-devices=interface-name:r130usb0
[device]
wifi.backend=wpa_supplicant
wifi.scan-rand-mac-address=no
[connection]
# ath11k (QCA6390) on this port fails association with PMF negotiated (CONN_FAILED)
wifi-sec.pmf=1
C
ssid=$(sed -n 's/^[[:space:]]*ssid="\(.*\)"[[:space:]]*$/\1/p' $src | head -1)
psk=$(sed -n 's/^[[:space:]]*psk=\([0-9a-fA-F]\{64\}\)[[:space:]]*$/\1/p' $src | head -1)
if [ -n "$ssid" ] && [ -n "$psk" ]; then
	f=/etc/NetworkManager/system-connections/tb371fc-home.nmconnection
	umask 077
	printf '[connection]\nid=%s\ntype=wifi\nautoconnect=true\nautoconnect-priority=10\n\n[wifi]\nmode=infrastructure\nssid=%s\n\n[wifi-security]\nkey-mgmt=wpa-psk\npmf=1\npsk=%s\n\n[ipv4]\nmethod=auto\n\n[ipv6]\nmethod=auto\n' "$ssid" "$ssid" "$psk" > $f
	chmod 600 $f
	echo "R166 nm: home profile written"
else
	echo "R166 nm: no usable ssid/psk in $src"
fi
# stop the direct wpa_supplicant/dhcpcd started by r163-wifi.sh, then start NetworkManager
dhcpcd -x wlp1s0 2>/dev/null
pkill -f "wpa_supplicant .*-i wlp1s0" 2>/dev/null
sleep 1
ip addr flush dev wlp1s0 2>/dev/null
systemctl start NetworkManager
for i in $(seq 1 40); do nmcli -t -f DEVICE,STATE dev 2>/dev/null | grep -q '^wlp1s0:connected$' && break; sleep 1; done
nmcli -t -f DEVICE,TYPE,STATE dev
# the clock: timesyncd may have given up before the network existed
systemctl restart systemd-timesyncd
echo "R166 nm: done uptime=$(cut -d' ' -f1 /proc/uptime)"
