#!/usr/bin/env bash
# R171: read-only layer with bluez-qt 6.28.0 + bluedevil 6.7.4 built on the tablet (matches KF 6.28 /
# Plasma 6.7.4 / Qt 6.11). Mounted above r163-apps by the R171 loader (marker /etc/tb371fc-r171-apps-layer).
set -euo pipefail
d=/mnt/d/TB371FC-builds/r171-bt; st=/root/tb371fc/r171-layer-stage; img=$d/r171-apps.img
rm -rf $st $st.x; mkdir -p $st $st.x
tar -xf $d/bd-stage.tar -C $st.x
cp -a $st.x/bluez-qt/. $st/; cp -a $st.x/bluedevil/. $st/
mkdir -p $st/etc; echo "R171 apps layer: bluez-qt 6.28.0 + bluedevil 6.7.4 (built on the tablet), $(date -u +%FT%TZ)" > $st/etc/tb371fc-r171-apps-layer
find $st -type f | wc -l; du -sh $st
test -f $st/usr/lib/qt6/plugins/kf6/kded/bluedevil.so
rm -f $img; mkfs.ext4 -q -F -L r171apps -m 0 -O ^has_journal -E root_owner=0:0 -d $st $img 48M
e2fsck -fn $img | tail -1; ls -la $img; sha256sum $img | tee $d/r171-apps.img.sha256
