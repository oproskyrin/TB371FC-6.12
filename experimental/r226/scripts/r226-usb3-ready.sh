#!/bin/sh
set -eu
grep -qw tb371fc.usb3test /proc/cmdline
test "$(tr -d '\000' </proc/device-tree/chosen/tb371fc,experiment)" = r207-ps5169-usb3
# Keep Wi-Fi SSH available before touching the USB candidate.
n=0
while ! ip -4 -o addr show scope global | grep -q 'wlp1s0'; do
 n=$((n+1)); [ "$n" -lt 90 ] || exit 1; sleep 1
done
p=/sys/bus/platform/devices/88e8000.phy
test ! -L "$p/driver"
test ! -e /sys/class/udc/a600000.usb
echo r209-qmp-combo-phy > "$p/driver_override"
insmod /run/r226/aux-hpd-bridge.ko
insmod /run/r226/r209-qmp.ko
insmod /run/r226/r203-usb-regulators.ko
sleep 3
test "$(basename "$(readlink "$p/driver")")" = r209-qmp-combo-phy
test -e /sys/class/udc/a600000.usb
# Same known-working cable orientation as R209. Not automatic Type-C/host/DP.
insmod /run/r226/r207-ps5169.ko fine_lfps=1 orientation=2
/bin/sh /run/r226/r203-retry-usb-gadget.sh
sleep 4
cat /sys/class/udc/a600000.usb/current_speed /sys/class/udc/a600000.usb/state
