#!/bin/sh
set -eu
mkdir -p /run/r130/modules /run/r130/config
cp /bin/busybox /run/r130/busybox
cp /r130-modules/*.ko /run/r130/modules/
cp /r130-config/* /run/r130/config/
chmod 0755 /run/r130/busybox /run/r130/config/*.sh
echo 'R130: USB activation deferred until Arch multi-user; R129 overlay path retained'
exec /bin/boot-arch-r129-base
