#!/bin/sh
set -eu
test -e /sys/class/udc/a600000.usb
src=/run/r130/config/start-usb.sh
test -f "$src"
g=/sys/kernel/config/usb_gadget/tb371fc-r130
if [ -d "$g" ]; then
 echo 'Existing gadget found; inspect before any alteration'
 cat "$g/UDC" "$g/max_speed" 2>/dev/null || true
 exit 1
fi
mkdir -p /run/r203-usb
# Derive the unchanged gadget setup, skipping only already-loaded driver insmods.
sed '/timeout.*insmod/d; s/0x0200/0x0300/' "$src" > /run/r203-usb/start-gadget.sh
/run/r130/busybox sh /run/r203-usb/start-gadget.sh
cat /sys/class/udc/a600000.usb/current_speed
