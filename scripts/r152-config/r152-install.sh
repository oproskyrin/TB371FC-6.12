#!/bin/sh
set -eu
cfg=/run/r130/config
chmod 0600 "$cfg/r152-wpa.conf"
cp "$cfg/r152-wifi.service" /etc/systemd/system/
chmod 0644 /etc/systemd/system/r152-wifi.service
systemctl daemon-reload
echo 'R152: starting Wi-Fi'
systemctl --no-block start r152-wifi.service
