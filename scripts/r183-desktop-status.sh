#!/bin/sh
set -u
cat /proc/uptime
systemctl is-active r149-plasma.service r183-software-rollback.timer
runuser -u alarm -- env XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus qdbus6 org.kde.KWin /KWin supportInformation
journalctl -b --since '-5 min' --no-pager _UID=1000 | grep -iE 'kwin_wayland_drm|pageflip|EGL|GL error|import|OpenGL|failed to' | tail -65
dmesg | tail -25
