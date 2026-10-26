#!/usr/bin/env bash
# R163: build the read-only apps layer (Chromium + deps, pacman db) from the RAM-upper tar taken
# on the tablet. Runtime state written by our boot scripts is excluded.
set -euo pipefail
d=/mnt/d/TB371FC-builds/r163-layer
st=/root/tb371fc/r163-layer-stage; img=$d/r163-apps.img
tar -tf $d/r163-upper.tar > /dev/null && echo "tar ok: $(tar -tf $d/r163-upper.tar | wc -l) entries"
rm -rf $st; mkdir -p $st
tar -xpf $d/r163-upper.tar --numeric-owner -C $st
rm -rf $st/etc/systemd $st/etc/udev $st/etc/ssh $st/etc/pipewire $st/etc/wireplumber $st/etc/machine-id \
       $st/etc/fstab $st/etc/localtime $st/etc/resolv.conf $st/etc/adjtime $st/etc/.pwd.lock
ls $st $st/etc | tr '\n' ' '; echo
test -x $st/usr/lib/chromium/chromium
grep -q '^%NAME%' $st/var/lib/pacman/local/chromium-*/desc
echo "R163 apps layer: $(ls -d $st/var/lib/pacman/local/chromium-* | xargs basename), built $(date -u +%FT%TZ)" > $st/etc/tb371fc-r163-apps-layer
find $st \( -type c -o -type b \) | head
sz=$(( $(du -sm $st | cut -f1) * 13 / 10 + 64 ))
rm -f $img; mkfs.ext4 -q -F -L r163apps -m 0 -O ^has_journal -E root_owner=0:0 -d $st $img ${sz}M
e2fsck -fn $img | tail -2
ls -la $img; sha256sum $img | tee $d/r163-apps.img.sha256
