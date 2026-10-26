#!/bin/sh
set -eu
mkdir -p /run/r134/config /run/r134/modules
cp /r134-config/* /run/r134/config/
cp /r134-modules/* /run/r134/modules/
chmod 0755 /run/r134/config/*.sh
echo 'R134 CONTROL: backported panel available but DSI/GPIO gates remain closed'
exec /bin/boot-arch-r130-wrapper
