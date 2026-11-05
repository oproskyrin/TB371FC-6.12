#!/bin/sh
set -eu
grep -qw tb371fc.r228 /proc/cmdline
if mountpoint -q /run/media/alarm/r228-usb; then
 test "$(findmnt -n -o SOURCE /run/media/alarm/r228-usb)" = /dev/sda1
 umount /run/media/alarm/r228-usb
fi
mode=/sys/kernel/debug/usb/a600000.usb/mode
printf 'device\n' > "$mode"
n=0
while [ ! -e /sys/class/udc/a600000.usb ]; do
 n=$((n+1)); [ "$n" -lt 20 ] || exit 1; sleep 1
done
g=/sys/kernel/config/usb_gadget/tb371fc-r130
test -d "$g"
if [ -z "$(cat "$g/UDC")" ]; then printf 'a600000.usb\n' > "$g/UDC"; fi
echo 'R228 returned to DEVICE; no PMIC/VBUS writes performed'
