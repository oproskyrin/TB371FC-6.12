#!/bin/sh
set -eu
systemctl stop r149-plasma.service || true
loginctl terminate-user alarm || true
rm -f /run/systemd/system/r149-plasma.service.d/90-r183-gpu.conf
systemctl daemon-reload
systemctl start r149-plasma.service
echo 'R183: returned to baseline QPainter service'
