#!/bin/sh
set -eu
grep -qw tb371fc.r226 /proc/cmdline
grep -qw tb371fc.usb3test /proc/cmdline
uname -r
findmnt -n -o SOURCE,FSTYPE,OPTIONS /
cat /sys/kernel/debug/mmc0/ios
grep -q 'actual clock:.*150000000 Hz' /sys/kernel/debug/mmc0/ios
systemctl is-active r149-plasma.service tb371fc-native-display.service tb371fc-rescue-sshd.service
systemctl status r226-touch-ready.service r226-usb3-ready.service --no-pager -l
cat /proc/interrupts | grep NVT
cat /sys/class/udc/a600000.usb/current_speed /sys/class/udc/a600000.usb/state
cat /sys/kernel/debug/usb/a600000.usb/link_state
cat /sys/kernel/debug/mmc0/err_stats
journalctl -b -u r226-touch-ready.service -u r226-usb3-ready.service --no-pager -n 50
echo 'R226 live checks read; real finger input and visible display still require confirmation'
