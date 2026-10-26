#!/bin/sh
# TB371FC Opus phase 1 - READ-ONLY. Ничего не меняет.
# Цель: подтвердить механизм дрожания (runtime PM microSD + printk flood).
echo "===== PHASE1 BEGIN ====="
echo "--- date/uptime ---"; date -Ins; uptime
echo "--- /proc/cmdline ---"; cat /proc/cmdline
echo "--- printk loglevel (console/default/min/boot) ---"; cat /proc/sys/kernel/printk
echo "--- консоли ядра ---"; cat /proc/consoles 2>/dev/null || echo "(нет /proc/consoles)"
echo "--- fbcon bind ---"; for v in /sys/class/vtconsole/*/; do echo "$v: $(cat $v/name 2>/dev/null) bind=$(cat $v/bind 2>/dev/null)"; done

echo
echo "===== MMC / microSD (корень системы!) ====="
for h in /sys/class/mmc_host/mmc*; do
  echo "== $h -> $(readlink -f $h)"
  d="$h/device"
  for k in power/control power/runtime_status power/runtime_suspended_time power/runtime_active_time power/autosuspend_delay_ms; do
    [ -e "$d/$k" ] && echo "   device/$k = $(cat $d/$k 2>/dev/null)"
  done
  for k in power/control power/runtime_status power/autosuspend_delay_ms; do
    [ -e "$h/$k" ] && echo "   host/$k = $(cat $h/$k 2>/dev/null)"
  done
  for c in "$h"/mmc*:*; do
    [ -d "$c" ] || continue
    echo "   card $c type=$(cat $c/type 2>/dev/null) name=$(cat $c/name 2>/dev/null)"
    for k in power/control power/runtime_status power/autosuspend_delay_ms; do
      [ -e "$c/$k" ] && echo "      $k = $(cat $c/$k 2>/dev/null)"
    done
  done
done
echo "--- какое устройство держит корень ---"
losetup -a 2>/dev/null
echo "--- diskstats mmcblk ---"; grep mmcblk /proc/diskstats 2>/dev/null
echo "--- дерево sdhci power/control ---"
find /sys/devices -path '*sdhci*/power/control' 2>/dev/null | while read p; do
  echo "   $p = $(cat $p 2>/dev/null) status=$(cat $(dirname $p)/runtime_status 2>/dev/null) delay=$(cat $(dirname $p)/autosuspend_delay_ms 2>/dev/null)"
done

echo
echo "===== НАГРУЗКА (loadavg был 2.00 при 0 пользователей) ====="
echo "--- loadavg ---"; cat /proc/loadavg
echo "--- топ по CPU ---"; ps -eo pcpu,pid,stat,comm --sort=-pcpu 2>/dev/null | head -20
echo "--- процессы в D-state (ждут I/O) ---"; ps -eo stat,pid,wchan:24,comm 2>/dev/null | awk 'NR==1 || $1 ~ /^D/'
echo "--- PSI (если есть) ---"; for p in cpu io memory; do [ -e /proc/pressure/$p ] && echo "$p: $(cat /proc/pressure/$p | tr '\n' ' ')"; done
echo "--- vmstat ---"; vmstat 1 3 2>/dev/null || echo "(нет vmstat)"

echo
echo "===== KWIN (реальный процесс, не wrapper) ====="
KW=$(pgrep -f '/opt/tb371fc-kwin-renderloopfix/bin/kwin_wayland' 2>/dev/null | head -1)
[ -z "$KW" ] && KW=$(pgrep -f 'kwin_wayland --wayland-fd' 2>/dev/null | head -1)
echo "pid=$KW  exe=$(readlink -f /proc/$KW/exe 2>/dev/null)"
echo "--- environ ---"; tr '\0' '\n' < /proc/$KW/environ 2>/dev/null | grep -iE 'KWIN|MESA|LIBGL|LD_LIBRARY|QT_|WAYLAND' | sort
echo "--- CPU время / состояние ---"; ps -o pid,stat,pcpu,etime,time,wchan:24,comm -p "$KW" 2>/dev/null
echo "--- версия ---"; /opt/tb371fc-kwin-renderloopfix/bin/kwin_wayland --version 2>&1 | head -3

echo
echo "===== DRM =====" 
for c in /sys/class/drm/card0-*/; do
  s=$(cat "$c/status" 2>/dev/null); [ "$s" = connected ] || continue
  echo "== $c status=$s"
  echo "   modes: $(tr '\n' ' ' < $c/modes 2>/dev/null)"
  [ -e "$c/edid" ] && echo "   edid bytes: $(wc -c < $c/edid)"
done
echo "--- kscreen / kwinoutputconfig ---"
ls -la /root/.local/share/kscreen 2>/dev/null
for f in /root/.local/share/kwin/kwinoutputconfig.json /root/.config/kwinoutputconfig.json; do
  [ -e "$f" ] && { echo "== $f"; cat "$f"; }
done
echo "--- бэкапы ---"; ls -la /var/backups/tb371fc 2>/dev/null

echo
echo "===== ЖУРНАЛ (почему пуст) ====="
echo "--- journald ---"; systemctl is-active systemd-journald 2>/dev/null; ls -la /var/log/journal 2>/dev/null || echo "(нет /var/log/journal - журнал volatile)"
ls -la /run/log/journal 2>/dev/null | head -5
echo "--- Storage= ---"; grep -hE '^\s*Storage' /etc/systemd/journald.conf /etc/systemd/journald.conf.d/*.conf 2>/dev/null || echo "(Storage не задан)"
echo "--- юниты в состоянии failed ---"; systemctl --failed --no-pager 2>/dev/null | head -20
echo "===== PHASE1 END ====="
