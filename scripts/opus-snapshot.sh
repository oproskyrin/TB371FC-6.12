#!/bin/sh
# TB371FC read-only baseline snapshot (Opus phase 0).
# Ничего не меняет на планшете. Только читает состояние.
echo "===== SNAPSHOT BEGIN ====="
echo "--- date ---";            date -Ins 2>&1
echo "--- uname ---";           uname -a 2>&1
echo "--- v56 kde status ---";  cat /run/tb371fc-v56-kde-status 2>&1 || echo "(нет маркера)"
echo "--- uptime ---";          uptime 2>&1
echo "--- ip -br address ---";  ip -br address 2>&1
echo "--- findmnt ---";         findmnt 2>&1
echo "--- dri / kgsl ---";      ls -l /dev/dri /dev/kgsl-3d0 2>&1
echo "--- compositor procs ---"; ps -ef 2>&1 | grep -E '[k]win_wayland|[p]lasmashell|[s]ddm|[s]eatd' 2>&1
echo "--- ЭКСПЕРИМЕНТАЛЬНЫЙ LAUNCHER (главная проверка) ---"
if [ -e /usr/local/bin/kwin_wayland ]; then
  echo "!!! /usr/local/bin/kwin_wayland СУЩЕСТВУЕТ"
  readlink -f /usr/local/bin/kwin_wayland 2>&1
  ls -l /usr/local/bin/kwin_wayland 2>&1
  echo "--- содержимое ---"
  sed -n '1,160p' /usr/local/bin/kwin_wayland 2>&1
else
  echo "OK: /usr/local/bin/kwin_wayland отсутствует"
fi
echo "--- какой kwin_wayland будет выбран ---"; command -v kwin_wayland 2>&1
echo "--- renderloopfix prefix ---"; ls -la /opt/tb371fc-kwin-renderloopfix 2>&1 || echo "(нет)"
echo "--- активен ли refreshfix ---"; ls -l /run/tb371fc-kwin-refreshfix-active 2>&1 || echo "(нет маркера)"
echo "--- kwin environment ---"
KWPID=$(pgrep -o kwin_wayland 2>/dev/null)
if [ -n "$KWPID" ]; then
  echo "kwin_wayland pid=$KWPID"
  tr '\0' '\n' < "/proc/$KWPID/environ" 2>&1 | sort
  echo "--- состояние процесса (D-state?) ---"
  ps -o pid,stat,wchan:32,cmd -p "$KWPID" 2>&1
else
  echo "kwin_wayland НЕ ЗАПУЩЕН"
fi
echo "--- DRM connectors/modes ---"
for c in /sys/class/drm/card*/; do
  [ -e "$c/status" ] || continue
  echo "== $c"; cat "$c/status" 2>&1; cat "$c/modes" 2>&1
done
echo "--- backup dir ---"; ls -la /var/backups/tb371fc 2>&1 || echo "(нет)"
echo "--- сбор больших логов во временные файлы ---"
journalctl -b --no-pager > /var/tmp/journal-current-boot.txt 2>&1; echo "journal: $(wc -l < /var/tmp/journal-current-boot.txt 2>/dev/null) строк"
dmesg -T > /var/tmp/dmesg-current-boot.txt 2>&1;                  echo "dmesg:   $(wc -l < /var/tmp/dmesg-current-boot.txt 2>/dev/null) строк"
echo "--- последние 80 строк journal ---"; tail -n 80 /var/tmp/journal-current-boot.txt 2>&1
echo "--- ошибки DRM/SDE/KGSL из dmesg ---"; grep -iE 'sde|drm|kgsl|dsi|panic|Oops' /var/tmp/dmesg-current-boot.txt 2>/dev/null | tail -n 60
echo "===== SNAPSHOT END ====="
