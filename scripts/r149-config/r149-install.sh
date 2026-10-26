#!/bin/sh
# R149: install touch calibration + touch/KDE units in RAM, then start them.
set -eu
cfg=/run/r130/config
mkdir -p /etc/udev/rules.d /etc/systemd/system
cp "$cfg/99-tb371fc-touch.rules" /etc/udev/rules.d/
cp "$cfg/r149-touch.service" "$cfg/r149-plasma.service" /etc/systemd/system/
chmod 0644 /etc/udev/rules.d/99-tb371fc-touch.rules /etc/systemd/system/r149-*.service
udevadm control --reload
systemctl daemon-reload
echo 'R149: starting touchscreen and KDE Plasma on tty7'
systemctl --no-block start r149-touch.service
systemctl --no-block start r149-plasma.service
