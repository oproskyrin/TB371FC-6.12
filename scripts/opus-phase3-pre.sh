#!/bin/sh
# TB371FC Opus phase 3, часть A: измерить -> снять экспериментальный launcher -> перезагрузить.
# Одна гипотеза: KWIN_DRM_RENDERLOOP_REFRESH_RATE_MHZ=60000 сорвал планировщик кадров KWin.
# Откат: /var/backups/tb371fc/opus-restore-<stamp>/rollback.sh
set -u
STAMP=$(date +%Y%m%d-%H%M%S)
BK=/var/backups/tb371fc/opus-restore-$STAMP
echo "===== PHASE3-PRE BEGIN ($STAMP) ====="

echo "--- измерение ДО (10 c) ---"
A=$(grep -icE 'mdss|sde|dsi' /proc/interrupts)
snapirq() { grep -iE 'mdss|sde|dsi|kgsl' /proc/interrupts; }
T1=$(mktemp); snapirq > "$T1"; D1=$(dmesg | wc -l)
sleep 10
T2=$(mktemp); snapirq > "$T2"; D2=$(dmesg | wc -l)
awk 'NR==FNR{n=$0;sub(/:.*/,"",n);gsub(/ /,"",n);s=0;for(i=2;i<=NF;i++)if($i~/^[0-9]+$/)s+=$i;a[n]=s;next}
     {n=$0;sub(/:.*/,"",n);gsub(/ /,"",n);s=0;for(i=2;i<=NF;i++)if($i~/^[0-9]+$/)s+=$i;d=s-a[n];
      l=$0;sub(/^[^:]*:[ \t]*/,"",l);split(l,p," ");t="";for(i=1;i<=length(p);i++)if(p[i]!~/^[0-9]+$/)t=t" "p[i];
      printf "  irq %-6s delta=%-8d %7.2f/s %s\n",n,d,d/10,t}' "$T1" "$T2"
rm -f "$T1" "$T2"
echo "  printk: $(( (D2 - D1) / 10 )) сообщений/сек"
echo "  loadavg: $(cat /proc/loadavg)"
echo "  kwin: $(ps -o pid,stat,pcpu,time,wchan:20,comm -p "$(pgrep -f '/opt/tb371fc-kwin-renderloopfix/bin/kwin_wayland' | head -1)" 2>/dev/null | tail -1)"

echo
echo "--- бинарники ---"
md5sum /usr/bin/kwin_wayland /opt/tb371fc-kwin-renderloopfix/bin/kwin_wayland 2>/dev/null
ls -la /opt/tb371fc-kwin-renderloopfix/lib 2>/dev/null

echo
echo "--- конфиги вывода ---"
for f in /root/.config/kwinoutputconfig.json \
         /var/backups/tb371fc/kwinoutputconfig.pre-renderloopfix.json \
         /var/backups/tb371fc/kwinoutputconfig.pre-refreshfix.json; do
  echo "== $f : $(grep -o '"refreshRate":[^,]*' "$f" 2>/dev/null | head -1)  md5=$(md5sum "$f" 2>/dev/null | cut -d' ' -f1)"
done

echo
echo "===== ИЗМЕНЕНИЕ (одна переменная) ====="
mkdir -p "$BK"
if [ -e /usr/local/bin/kwin_wayland ]; then
  cp -a /usr/local/bin/kwin_wayland "$BK/kwin_wayland.renderloopfix.disabled"
  cp -a /root/.config/kwinoutputconfig.json "$BK/kwinoutputconfig.at-removal.json" 2>/dev/null
  rm -f /usr/local/bin/kwin_wayland
  echo "СНЯТ: /usr/local/bin/kwin_wayland  (копия в $BK)"
else
  echo "launcher уже отсутствует"
fi
# конфиг вывода НЕ трогаем - это была бы вторая переменная в одном тесте
cat > "$BK/rollback.sh" <<EOR
#!/bin/sh
# Вернуть экспериментальный renderloopfix launcher.
cp -a "$BK/kwin_wayland.renderloopfix.disabled" /usr/local/bin/kwin_wayland
chmod 755 /usr/local/bin/kwin_wayland
echo "launcher восстановлен; нужна перезагрузка"
EOR
chmod +x "$BK/rollback.sh"
echo "откат готов: $BK/rollback.sh"

hash -r 2>/dev/null || true
echo "теперь будет выбран: $(command -v kwin_wayland)"
echo "$BK" > /var/backups/tb371fc/.opus-last-restore

echo
echo "===== ПЕРЕЗАГРУЗКА ====="
sync; sync
echo "reboot..."
( sleep 2; systemctl reboot || reboot ) >/dev/null 2>&1 &
echo "===== PHASE3-PRE END ====="
exit 0
