#!/bin/sh
# R173: QCA6390 Bluetooth over UART6 (ttyHS1). Started after Wi-Fi and the desktop settle: under
# boot load the 3.2 Mbit/s firmware download often times out (-110). The chip has no BD address
# of its own; setting one re-runs the firmware setup, so the whole sequence (load, firmware,
# address, configured controller) is retried as one unit, up to 5 times.
set -u
exec >>/run/r171-bt.log 2>&1
echo "R171 bt: start uptime=$(cut -d' ' -f1 /proc/uptime)"
root=/run/r163-modroot
for i in $(seq 1 180); do grep -q -E "R163 wifi: (started|no wlp1s0)" /run/r163-wifi.log 2>/dev/null && break; sleep 1; done
for i in $(seq 1 120); do pgrep -x plasmashell >/dev/null && break; sleep 1; done
sleep 15
# stable source: the boot microSD serial (machine-id is regenerated each boot, soc0 is absent)
s=$(cat /sys/bus/mmc/devices/mmc0:*/serial 2>/dev/null | head -1); [ -n "$s" ] || s=$(cat /sys/class/net/wlp1s0/address 2>/dev/null)
h=$(printf '%s' "tb371fc-bt-$s" | md5sum | cut -c1-10)
addr=$(printf '02:%s:%s:%s:%s:%s' $(echo $h | cut -c1-2) $(echo $h | cut -c3-4) $(echo $h | cut -c5-6) $(echo $h | cut -c7-8) $(echo $h | cut -c9-10) | tr a-f A-F)
done_n() { dmesg | grep -c "QCA setup on UART is completed"; }
configured() { btmgmt info 2>/dev/null | grep -q "Primary controller"; }
ok=0
for try in 1 2 3 4 5; do
	n0=$(done_n)
	for m in btqca hci_uart; do timeout 60 modprobe -d $root $m || echo "R171 bt: modprobe $m rc=$?"; done
	for i in $(seq 1 30); do [ "$(done_n)" -gt "$n0" ] && ls /sys/class/bluetooth 2>/dev/null | grep -q "^hci" && break; sleep 1; done
	sleep 2
	# the index is not always 0 (a stuck earlier instance keeps hci0 until it is removed)
	idx=$(ls /sys/class/bluetooth 2>/dev/null | grep "^hci[0-9]*$" | head -1 | cut -c4-)
	if btmgmt --index "${idx:-0}" config 2>/dev/null | grep -q "missing options: public-address"; then
		n0=$(done_n)
		btmgmt --index "${idx:-0}" public-addr "$addr" >/dev/null && echo "R171 bt: stable BD address set (try $try)"
		for i in $(seq 1 30); do [ "$(done_n)" -gt "$n0" ] && configured && break; sleep 1; done
	fi
	if configured; then ok=1; break; fi
	echo "R171 bt: controller not ready, retry $try"
	timeout 120 modprobe -r -d $root hci_uart; sleep 3
done
[ $ok = 1 ] || { echo "R171 bt: FAILED"; exit 0; }
systemctl restart bluetooth
sleep 3
bluetoothctl power on >/dev/null
bluetoothctl system-alias "Lenovo TB371FC" >/dev/null
echo "R171 bt: done uptime=$(cut -d' ' -f1 /proc/uptime)"
