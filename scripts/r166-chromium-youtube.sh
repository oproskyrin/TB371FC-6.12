#!/bin/sh
# R166 check: open YouTube in Chromium on the tablet screen (user session) and report what loaded.
pid=$(pgrep -u alarm -x plasmashell | head -1); [ -n "$pid" ] || { echo "no plasmashell"; exit 1; }
tr '\0' '\n' < /proc/$pid/environ | grep -E '^(WAYLAND_DISPLAY|DISPLAY|XDG_[A-Z_]+|DBUS_SESSION_BUS_ADDRESS|QT_[A-Z_]+|KDE_[A-Z_]+|XAUTHORITY|LANG|LC_[A-Z]+|PATH|HOME|USER|SHELL)=' | sed 's/^/export /; s/=\(.*\)$/="\1"/' > /run/plasma-env.sh
chown alarm /run/plasma-env.sh
su alarm -s /bin/sh -c '. /run/plasma-env.sh; setsid nohup chromium --remote-debugging-port=9222 --no-first-run --password-store=basic https://www.youtube.com/ >/tmp/chromium.log 2>&1 < /dev/null &'
for i in $(seq 1 60); do curl -s http://127.0.0.1:9222/json 2>/dev/null | grep -q '"type": "page"' && break; sleep 1; done
sleep 15
curl -s http://127.0.0.1:9222/json | grep -E '"(title|url)"' | head -6
uptime; for z in /sys/class/thermal/thermal_zone*; do cat $z/temp; done | sort -n | tail -1 | awk '{print "max temp " $1/1000 " C"}'
grep -v -i -E "fontconfig|dbus" /tmp/chromium.log | tail -5 | cut -c1-160
