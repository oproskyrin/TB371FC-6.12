#!/bin/sh
# TB371FC Opus phase 2 - READ-ONLY измерение частоты кадров/vblank.
# Ничего не меняет. Только считает дельты за 10 секунд.
W=10
echo "===== PHASE2 BEGIN (окно $W c) ====="
date -Ins

snap() {
  grep -iE 'mdss|sde|dsi|kgsl|8804000|disp' /proc/interrupts 2>/dev/null
}
echo "--- строки IRQ, которые считаем ---"; snap | sed 's/^\(.\{100\}\).*/\1/'

A_IRQ=$(mktemp); B_IRQ=$(mktemp)
snap > "$A_IRQ"
A_DMESG=$(dmesg 2>/dev/null | wc -l)
A_ACT=$(cat /sys/devices/platform/soc/8804000.sdhci/power/runtime_active_time 2>/dev/null)
A_SUS=$(cat /sys/devices/platform/soc/8804000.sdhci/power/runtime_suspended_time 2>/dev/null)
A_DISK=$(awk '$3=="mmcblk0"{print $4" "$8}' /proc/diskstats)
A_CPU=$(head -1 /proc/stat)
sleep $W
snap > "$B_IRQ"
B_DMESG=$(dmesg 2>/dev/null | wc -l)
B_ACT=$(cat /sys/devices/platform/soc/8804000.sdhci/power/runtime_active_time 2>/dev/null)
B_SUS=$(cat /sys/devices/platform/soc/8804000.sdhci/power/runtime_suspended_time 2>/dev/null)
B_DISK=$(awk '$3=="mmcblk0"{print $4" "$8}' /proc/diskstats)
B_CPU=$(head -1 /proc/stat)

echo
echo "===== ЧАСТОТА ПРЕРЫВАНИЙ (ключевое) ====="
awk -v w="$W" '
  NR==FNR { name=$0; sub(/:.*/,"",name); gsub(/ /,"",name);
            s=0; for(i=2;i<=NF;i++) if ($i ~ /^[0-9]+$/) s+=$i; a[name]=s; next }
  { name=$0; sub(/:.*/,"",name); gsub(/ /,"",name);
    s=0; for(i=2;i<=NF;i++) if ($i ~ /^[0-9]+$/) s+=$i;
    d=s-a[name];
    label=$0; sub(/^[^:]*:[ \t]*/,"",label);
    n=split(label,p," "); tail="";
    for(i=1;i<=n;i++) if (p[i] !~ /^[0-9]+$/) tail=tail" "p[i];
    printf "  irq %-6s delta=%-8d %7.2f/s  %s\n", name, d, d/w, tail }
' "$A_IRQ" "$B_IRQ"
rm -f "$A_IRQ" "$B_IRQ"

echo
echo "===== ПОТОК printk ====="
echo "  строк dmesg: $A_DMESG -> $B_DMESG  = $(( (B_DMESG - A_DMESG) / W )) /сек"
echo "  ignore_loglevel = $(cat /sys/module/printk/parameters/ignore_loglevel 2>/dev/null || echo '(нет параметра)')"
echo "  printk = $(cat /proc/sys/kernel/printk)"
echo "  consoles:"; cat /proc/consoles 2>/dev/null | sed 's/^/    /'

echo
echo "===== microSD за окно ====="
echo "  active_time    $A_ACT -> $B_ACT  (+$(( B_ACT - A_ACT )) мс из ${W}000)"
echo "  suspended_time $A_SUS -> $B_SUS  (+$(( B_SUS - A_SUS )) мс)"
echo "  diskstats(reads writes) [$A_DISK] -> [$B_DISK]"

echo
echo "===== CPU за окно ====="
echo "  A: $A_CPU"
echo "  B: $B_CPU"

echo
echo "===== debugfs / DRM state ====="
mount | grep -i debugfs || echo "  debugfs НЕ смонтирован"
ls -la /sys/kernel/debug/dri 2>/dev/null | head || echo "  (нет /sys/kernel/debug/dri)"

echo
echo "===== renderloopfix: что там лежит ====="
ls -la /opt/tb371fc-kwin-renderloopfix/bin /opt/tb371fc-kwin-renderloopfix/lib 2>/dev/null
echo "--- штатный kwin ---"; ls -la /usr/bin/kwin_wayland; /usr/bin/kwin_wayland --version 2>&1 | head -2
echo "--- различаются ли бинарники ---"
md5sum /usr/bin/kwin_wayland /opt/tb371fc-kwin-renderloopfix/bin/kwin_wayland 2>/dev/null

echo
echo "===== конфиги вывода (для сравнения) ====="
for f in /root/.config/kwinoutputconfig.json \
         /var/backups/tb371fc/kwinoutputconfig.pre-renderloopfix.json \
         /var/backups/tb371fc/kwinoutputconfig.pre-refreshfix.json; do
  echo "== $f"
  grep -E '"(refreshRate|width|height|scale|connectorName|vrrPolicy)"' "$f" 2>/dev/null | sed 's/^/   /'
done
echo "===== PHASE2 END ====="
