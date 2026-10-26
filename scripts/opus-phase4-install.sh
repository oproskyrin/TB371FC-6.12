#!/bin/sh
# TB371FC Opus phase 4, часть A: установить one-shot dumbsync+120Hz launcher и перезагрузиться.
# Гипотеза: CPU-записи KWin в DRM dumb buffer не сбрасываются из кэша,
# дисплей читает старое содержимое DRAM -> регионы обновляются с задержкой в секунды.
set -u
STAMP=$(date +%Y%m%d-%H%M%S)
BK=/var/backups/tb371fc/opus-dumbsync-$STAMP
SRC=/var/tmp/tb371fc-kwin-dumbsync-120hz-oneshot.sh
LAUNCH=/usr/local/bin/kwin_wayland

echo "===== PHASE4-INSTALL BEGIN ($STAMP) ====="
echo "boot_id ДО: $(cat /proc/sys/kernel/random/boot_id)"
echo "uptime  ДО: $(cut -d' ' -f1 /proc/uptime)"
echo "kernel     : $(uname -r)"

echo
echo "--- предусловия ---"
FAIL=0
for f in /opt/tb371fc-kwin-dumbsync/bin/kwin_wayland /opt/tb371fc-kwin-dumbsync/lib/libkwin.so.6.7.4 /usr/bin/kwin_wayland; do
  if [ -e "$f" ]; then echo "  OK  $f"; else echo "  НЕТ $f"; FAIL=1; fi
done
if [ ! -f "$SRC" ]; then echo "  НЕТ $SRC (scp не доехал)"; FAIL=1; else echo "  OK  $SRC"; fi
if grep -q 'KWIN_DRM_DUMB_BUFFER_CPU_SYNC=1' "$SRC" 2>/dev/null && grep -q 'KWIN_DRM_RENDERLOOP_REFRESH_RATE_MHZ=120000' "$SRC" 2>/dev/null; then
  echo "  OK  скрипт содержит обе переменные"
else
  echo "  НЕТ ожидаемых переменных в $SRC"; FAIL=1
fi
if [ "$FAIL" -ne 0 ]; then echo "ПРЕРВАНО: предусловия не выполнены, ничего не менял"; exit 1; fi

echo
echo "--- текущее состояние графики ---"
echo "  DSI-1: $(cat /sys/class/drm/card0-DSI-1/status 2>/dev/null)"
KW=$(pgrep -x kwin_wayland | tail -1)
echo "  kwin pid=$KW exe=$(readlink -f /proc/$KW/exe 2>/dev/null)"
tr '\0' '\n' < /proc/$KW/environ 2>/dev/null | grep -E 'KWIN_DRM_DUMB|KWIN_DRM_RENDERLOOP|LIBGL' | sed 's/^/    /'

echo
echo "--- установка one-shot launcher ---"
mkdir -p "$BK"
if [ -e "$LAUNCH" ]; then
  cp -a "$LAUNCH" "$BK/kwin_wayland.previous"
  echo "  прежний launcher сохранён в $BK/kwin_wayland.previous"
else
  echo "  прежнего launcher не было (штатный /usr/bin/kwin_wayland)"
fi
install -m 755 "$SRC" "$LAUNCH"
echo "  установлен: $LAUNCH"
md5sum "$LAUNCH" "$SRC" | sed 's/^/    /'
cat > "$BK/rollback.sh" <<EOR
#!/bin/sh
rm -f $LAUNCH
[ -f "$BK/kwin_wayland.previous" ] && cp -a "$BK/kwin_wayland.previous" $LAUNCH
echo "откат выполнен; нужна перезагрузка"
EOR
chmod +x "$BK/rollback.sh"
echo "  откат: $BK/rollback.sh"
echo "  (плюс сам launcher самоудаляется через 300 c после старта KWin)"

echo
echo "===== ПЕРЕЗАГРУЗКА ====="
sync; sync
# PID1 здесь busybox, systemd нет. setsid отвязывает от SSH-сессии,
# иначе процесс умирает по SIGHUP при закрытии соединения (ошибка прошлой попытки).
setsid /bin/sh -c 'sleep 3; sync; reboot; sleep 20; reboot -f' </dev/null >/dev/null 2>&1 &
echo "команда перезагрузки отправлена (reboot, через 20 c запасной reboot -f)"
echo "===== PHASE4-INSTALL END ====="
exit 0
