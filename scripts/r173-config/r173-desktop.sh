#!/bin/sh
# R173/R175: runs as root right before KDE starts (ExecStartPre of r149-plasma.service).
# The Russian locale is generated whenever missing; the desktop defaults (Russian KDE, us/ru
# keyboard with Alt+Shift, 125 % scale) are applied only once, so on the persistent root the
# user's own settings are never overwritten. Marker: /var/lib/tb371fc/desktop-defaults-v1.
exec >>/run/r173-desktop.log 2>&1
sed -i 's/^#ru_RU.UTF-8 UTF-8/ru_RU.UTF-8 UTF-8/' /etc/locale.gen
locale -a | grep -q ru_RU.utf8 || locale-gen
[ -f /etc/locale.conf ] && grep -q '^LANG=' /etc/locale.conf || echo 'LANG=ru_RU.UTF-8' > /etc/locale.conf
mark=/var/lib/tb371fc/desktop-defaults-v1
if [ -f $mark ]; then
	echo "R173 desktop: defaults already applied, user settings kept"
	exit 0
fi
k() { runuser -u alarm -- kwriteconfig6 "$@"; }
k --file plasma-localerc --group Formats --key LANG ru_RU.UTF-8
k --file plasma-localerc --group Translations --key LANGUAGE ru
k --file kxkbrc --group Layout --key Use true
k --file kxkbrc --group Layout --key LayoutList us,ru
k --file kxkbrc --group Layout --key ResetOldOptions true
k --file kxkbrc --group Layout --key Options grp:alt_shift_toggle
# 125 % once: KWin rewrites kwinoutputconfig.json at startup, so set it inside the first session
# with a one-shot autostart entry that removes itself.
a=/home/alarm/.config/autostart; mkdir -p $a
cat > $a/tb371fc-scale-once.desktop <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=TB371FC first-boot scale
Exec=sh -c "sleep 3; kscreen-doctor output.Unknown-1.scale.1.25; rm -f ~/.config/autostart/tb371fc-scale-once.desktop"
X-KDE-autostart-phase=1
DESKTOP
rm -f $a/tb371fc-scale.desktop
chown -R alarm:alarm $a
mkdir -p /var/lib/tb371fc; : > $mark
echo "R173 desktop: first-boot defaults applied (ru_RU, us/ru, scale 1.25 once) uptime=$(cut -d' ' -f1 /proc/uptime)"
