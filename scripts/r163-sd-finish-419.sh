#!/bin/sh
# R163 (4.19 console): verify the uploaded apps layer, put it in place, enable autoboot, unmount.
set -eu
bb=/run/tb371fc-rescue/busybox
mnt=/mnt/r163-sd; l=$mnt/tb371fc-linux/layers
mountpoint -q "$mnt"
sync; echo 3 > /proc/sys/vm/drop_caches
h=$("$bb" sha256sum "$l/r163-apps.img.partial" | "$bb" awk '{print $1}')
echo "layer sha256=$h"
[ "$h" = 9f7318d8b930f1a94fa663065287ec81da129afc6cbb99adf4a849c5d00259fe ] || { echo "LAYER HASH FAIL"; exit 1; }
mv "$l/r163-apps.img.partial" "$l/r163-apps.img"
printf 'R163 autoboot payload, installed %s. Delete this ENABLE file to disable autoboot.\n' "$(date)" > "$mnt/tb371fc-linux/autoboot-6.12-r163/ENABLE"
sync
ls -la "$l" "$mnt/tb371fc-linux/autoboot-6.12-r163"
df -h "$mnt" | tail -1
umount "$mnt"
echo SD_INSTALL_OK
