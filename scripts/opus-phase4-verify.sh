#!/bin/sh
# TB371FC Opus phase 4, часть B: проверка после перезагрузки. READ-ONLY.
echo "===== PHASE4-VERIFY BEGIN ====="
echo "boot_id ПОСЛЕ: $(cat /proc/sys/kernel/random/boot_id)"
echo "uptime  ПОСЛЕ: $(cut -d' ' -f1 /proc/uptime) c"
echo "kernel        : $(uname -r)"
echo "kde status    : $(cat /run/tb371fc-v56-kde-status 2>/dev/null || echo '(нет)')"
echo "DSI-1         : $(cat /sys/class/drm/card0-DSI-1/status 2>/dev/null)"
echo
echo "--- ТЕСТ ЗАПУЩЕН? (все 4 признака обязательны) ---"
KW=$(pgrep -x kwin_wayland | tail -1)
EXE=$(readlink -f /proc/$KW/exe 2>/dev/null)
echo "  pid=$KW"
echo "  exe=$EXE"
case "$EXE" in *dumbsync*) echo "  [1/4] OK  бинарник из /opt/tb371fc-kwin-dumbsync";; *) echo "  [1/4] НЕТ тестового бинарника";; esac
ENVF=$(tr '\0' '\n' < /proc/$KW/environ 2>/dev/null)
echo "$ENVF" | grep -q 'KWIN_DRM_DUMB_BUFFER_CPU_SYNC=1'      && echo "  [2/4] OK  KWIN_DRM_DUMB_BUFFER_CPU_SYNC=1" || echo "  [2/4] НЕТ переменной sync"
echo "$ENVF" | grep -q 'KWIN_DRM_RENDERLOOP_REFRESH_RATE_MHZ=120000' && echo "  [3/4] OK  pacing 120000" || echo "  [3/4] НЕТ pacing"
grep -q 'tb371fc-kwin-dumbsync' /proc/$KW/maps 2>/dev/null   && echo "  [4/4] OK  libkwin из dumbsync загружена" || echo "  [4/4] НЕТ dumbsync libkwin в maps"
echo
echo "--- окружение KWin ---"; echo "$ENVF" | grep -E 'KWIN|LIBGL|MESA|QT_QUICK|QSG' | sort | sed 's/^/    /'
echo
echo "--- нагрузка ---"; ps -o pid,stat,pcpu,rss,etime,comm -p "$KW" 2>/dev/null
echo "  loadavg: $(cat /proc/loadavg)"
echo "  plasmashell: $(ps -eo pcpu,pid,comm | grep -w plasmashell | head -1)"
echo
echo "--- ошибки синхронизации / графики ---"
echo "  DMA_BUF_IOCTL_SYNC failed: $(dmesg 2>/dev/null | grep -ci 'DMA_BUF_IOCTL_SYNC')"
echo "  новые DRM/SDE/DSI/KGSL/IOMMU:"
dmesg 2>/dev/null | grep -iE 'sde|drm|kgsl|dsi|iommu|smmu' | tail -15 | sed 's/^/    /'
[ -z "$(dmesg 2>/dev/null | grep -iE 'sde|drm|kgsl|dsi|iommu|smmu')" ] && echo "    (нет ни одной строки - чисто)"
echo
echo "--- лог самоудаления launcher ---"
cat /var/tmp/tb371fc-kwin-dumbsync-120hz-oneshot-cleanup.log 2>/dev/null || echo "  (пока пусто, launcher удалится через 300 c)"
ls -l /usr/local/bin/kwin_wayland 2>/dev/null || echo "  /usr/local/bin/kwin_wayland уже удалён"
echo "===== PHASE4-VERIFY END ====="
