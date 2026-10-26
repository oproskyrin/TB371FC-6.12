#!/bin/sh
set -eu
/run/r130/busybox sh /run/r130/config/r129-evidence-original.sh
echo 'R130: Arch target reached; installing USB/SSH diagnostic services in RAM'
/run/r130/busybox sh /run/r130/config/install-arch.sh
systemctl daemon-reload
udevadm control --reload
networkctl reload
systemctl --no-block start r130-usb.service
