#!/bin/sh
# Read-only hardware survey on the R140 desktop (no writes, no module loads).
echo "== cpu"; nproc; cat /sys/devices/system/cpu/possible /sys/devices/system/cpu/present /sys/devices/system/cpu/online
echo "== input"; for d in /sys/class/input/input*; do echo "$(basename $d): $(cat $d/name 2>/dev/null)"; done
echo "== touch in DT"; find /proc/device-tree -iname '*touch*' -o -iname '*nvt*' -o -iname '*novatek*ts*' 2>/dev/null | head
for n in $(find /proc/device-tree/soc@0 -maxdepth 2 -name 'i2c@*' -o -maxdepth 2 -name 'spi@*' 2>/dev/null); do s=$(tr -d '\000' < $n/status 2>/dev/null); echo "$n status=${s:-none}"; done | head -40
echo "== i2c/spi buses"; ls /sys/bus/i2c/devices /sys/bus/spi/devices 2>/dev/null
echo "== net"; ip -br link; ls /sys/bus/pci/devices 2>/dev/null; find /proc/device-tree -maxdepth 3 -name 'pcie@*' | while read n; do echo "$n $(tr -d '\000' < $n/status 2>/dev/null)"; done
echo "== power"; ls /sys/class/power_supply 2>/dev/null
echo "== sound"; cat /proc/asound/cards 2>/dev/null
echo "== remoteproc"; ls /sys/class/remoteproc 2>/dev/null
echo "== firmware dirs"; ls /lib/firmware/qcom 2>/dev/null | head; ls /lib/firmware/ath11k 2>/dev/null
echo "== storage"; lsblk -o NAME,SIZE,RO,FSTYPE,MOUNTPOINTS | head
echo "== kernel cfg"; zcat /proc/config.gz 2>/dev/null | grep -E "CONFIG_(TOUCHSCREEN_NOVATEK|ATH11K|PCIE_QCOM|QCOM_Q6V5|SND_SOC_SM8250|BATTERY_QCOM|CHARGER_QCOM|QCOM_PMIC_GLINK|ARM_PSCI_CPUIDLE|HID_MULTITOUCH)"
