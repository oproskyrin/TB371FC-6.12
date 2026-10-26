#!/bin/sh
# R162: keep plasma-pa at the Plasma version (6.7.4) and restart plasmashell so the volume applet loads.
set -u
pacman -U --noconfirm /var/cache/pacman/pkg/plasma-pa-6.7.4-1-aarch64.pkg.tar.xz 2>&1 | tail -2
pacman -Q plasma-pa
U() { su alarm -c "XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus $*" 2>&1 | grep -v -i rtkit; }
U systemctl --user restart plasma-plasmashell.service
sleep 8
U systemctl --user is-active plasma-plasmashell.service
grep -rl "org.kde.plasma.volume" /home/alarm/.config/plasma-org.kde.plasma.desktop-appletsrc 2>/dev/null && grep -n "hiddenItems\|shownItems\|extraItems" /home/alarm/.config/plasma-org.kde.plasma.desktop-appletsrc | cut -c1-200
U pactl get-default-sink
