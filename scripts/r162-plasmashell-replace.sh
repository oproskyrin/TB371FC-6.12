#!/bin/sh
# R162: restart the running plasmashell in place (same session environment) to load plasma-pa.
set -u
pid=$(pgrep -u alarm -x plasmashell | head -1); [ -n "$pid" ] || { echo "no plasmashell"; exit 1; }
tr '\0' '\n' < /proc/$pid/environ | grep -E '^(WAYLAND_DISPLAY|DISPLAY|XDG_[A-Z_]+|DBUS_SESSION_BUS_ADDRESS|QT_[A-Z_]+|KDE_[A-Z_]+|XAUTHORITY|LANG|LC_[A-Z]+|PATH|HOME|USER|SHELL)=' | sed 's/^/export /; s/=\(.*\)$/="\1"/' > /run/plasma-env.sh
chown alarm /run/plasma-env.sh
su alarm -s /bin/sh -c '. /run/plasma-env.sh; setsid nohup plasmashell --replace >/tmp/plasmashell.log 2>&1 < /dev/null &'
sleep 10
pgrep -a -u alarm plasmashell
tail -5 /tmp/plasmashell.log | cut -c1-160
