#!/bin/sh
# R163 layer build step 2 (RAM): pack the package delta of the RAM upper into a read-only ext4
# layer image. Runtime state written by our boot scripts is excluded.
set -eu
up=/run/r129/rw/upper; st=/run/r163-layer; img=/run/r163-apps.img
rm -rf $st $img; mkdir -p $st
cd $up
for d in usr opt var/lib/pacman etc; do [ -e "$d" ] && cp -a --parents "$d" $st/; done
rm -rf $st/etc/systemd $st/etc/udev $st/etc/ssh $st/etc/pipewire $st/etc/machine-id $st/etc/fstab \
       $st/etc/localtime $st/etc/resolv.conf $st/etc/adjtime $st/etc/systemd 2>/dev/null || true
mkdir -p $st/etc; echo "R163 apps layer: chromium $(pacman -Q chromium | cut -d' ' -f2), built $(date -u +%FT%TZ)" > $st/etc/tb371fc-r163-apps-layer
du -sh $st
find $st/etc -maxdepth 2 | head -40
sz=$(( $(du -sm $st | cut -f1) * 13 / 10 + 64 ))
mkfs.ext4 -q -F -L r163apps -m 0 -O ^has_journal -d $st $img ${sz}M
ls -la $img; sha256sum $img
rm -rf $st
