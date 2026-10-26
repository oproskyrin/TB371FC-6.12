#!/bin/sh
# Start the reversible software-rendered Plasma test on tty7 (RAM only, /run).
set -eu
u=/run/systemd/system/r140-plasma-software.service
sed -e 's#/dev/tty2#/dev/tty7#' -e 's#UtmpIdentifier=tty2#UtmpIdentifier=tty7#' -e 's#XDG_VTNR=2#XDG_VTNR=7#' /run/r140-plasma-software.service.new > "$u"
grep -E "tty7|VTNR" "$u"
systemctl daemon-reload
systemctl stop r140-plasma-software.service 2>/dev/null || true
chvt 7
sleep 1
systemctl start r140-plasma-software.service
sleep 45
systemctl is-active r140-plasma-software.service || true
loginctl list-sessions --no-pager
pgrep -a -u alarm -f "kwin_wayland|plasmashell|ksmserver" || true
cat /sys/class/tty/tty0/active
cat /sys/kernel/debug/pm_genpd/mmcx/perf_state
journalctl -b --no-pager _UID=1000 --since "-70s" | grep -i -E "kwin_core|kwin_wayland_drm|Permission|plasmashell|qpainter" | head -20
