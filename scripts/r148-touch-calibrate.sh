#!/bin/sh
# Landscape KDE on a portrait-native NT36532 digitizer (measured 2026-10-24):
# screen left->right = touch Y 0..max, screen top->bottom = touch X max..0.
# libinput matrix: u = y, v = 1 - x  ->  "0 1 0 -1 0 1". RAM overlay only.
set -eu
cat > /etc/udev/rules.d/99-tb371fc-touch.rules <<'EOF'
SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="NVTCapacitiveTouchScreen", ENV{LIBINPUT_CALIBRATION_MATRIX}="0 1 0 -1 0 1"
SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="NVTCapacitivePen", ENV{LIBINPUT_CALIBRATION_MATRIX}="0 1 0 -1 0 1"
EOF
udevadm control --reload
rmmod nt36523_ts
sleep 1
insmod /run/nt36523_ts.ko
sleep 3
for e in $(grep -l NVTCapacitive /sys/class/input/event*/device/name | sed 's#/device/name##; s#.*/##'); do
    echo "$e $(cat /sys/class/input/$e/device/name): $(udevadm info -q property -n /dev/input/$e | grep CALIBRATION)"
done
dmesg | grep -E "NVT-ts-spi.*(success|end|fail|error)" | tail -3
