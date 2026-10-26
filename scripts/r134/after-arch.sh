#!/bin/sh
set -eu
/run/r130/busybox sh /run/r134/config/r130-after-arch.sh
cp /run/r134/config/r134-display-deps.service /etc/systemd/system/
chmod 0644 /etc/systemd/system/r134-display-deps.service
systemctl daemon-reload
systemctl --no-block start r134-display-deps.service
