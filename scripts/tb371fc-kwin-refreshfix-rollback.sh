#!/bin/sh
set -eu

log=/var/tmp/tb371fc-kwin-refreshfix-rollback.log

session_pid=$(pgrep -o -x plasmashell 2>/dev/null || pgrep -o -x kwin_wayland)
bus=$(tr '\0' '\n' <"/proc/$session_pid/environ" | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p')
runtime=$(tr '\0' '\n' <"/proc/$session_pid/environ" | sed -n 's/^XDG_RUNTIME_DIR=//p')

if findmnt -n -T /usr/bin/kwin_wayland | grep -q '^/usr/bin/kwin_wayland '; then
    umount /usr/bin/kwin_wayland
fi

DBUS_SESSION_BUS_ADDRESS="$bus" XDG_RUNTIME_DIR="$runtime" \
    qdbus6 org.kde.KWin /KWin restart >>"$log" 2>&1 || true

rm -f /run/tb371fc-kwin-refreshfix-active
