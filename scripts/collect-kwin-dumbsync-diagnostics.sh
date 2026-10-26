#!/bin/sh
# Collect a self-contained diagnostic snapshot for the TB371FC KWin
# DRM dumb-buffer CPU-sync one-shot test.

set -u

stamp=$(date +%Y%m%d-%H%M%S)
out="/var/tmp/tb371fc-kwin-dumbsync-${stamp}"
mkdir -p "$out"

pid=$(pgrep -f '/opt/tb371fc-kwin-dumbsync/bin/kwin_wayland' | head -n 1)

date -Ins >"$out/date.txt"
cat /proc/uptime >"$out/uptime.txt"
uname -a >"$out/uname.txt"
ps auxww >"$out/ps-auxww.txt"
ps -p "$pid" -o pid,ppid,etime,time,%cpu,%mem,rss,vsz,stat,args >"$out/kwin-process.txt"
tr '\0' '\n' <"/proc/$pid/environ" | sort >"$out/kwin-environ.txt"
cp "/proc/$pid/maps" "$out/kwin-maps.txt"
cp "/proc/$pid/status" "$out/kwin-status.txt"
cp "/proc/$pid/io" "$out/kwin-io.txt"
cp "/proc/$pid/sched" "$out/kwin-sched.txt"

dmesg >"$out/dmesg.txt"
cp /var/log/tb371fc-plasma-v56-1.log "$out/plasma.log"
cp /var/log/tb371fc-v56-1-services.log "$out/services.log"
cp /var/log/tb371fc-networkmanager.log "$out/networkmanager.log"

cat /sys/kernel/debug/dri/0/state >"$out/drm-state.txt" 2>&1 || true
cat /sys/kernel/debug/dri/0/clients >"$out/drm-clients.txt" 2>&1 || true
cat /sys/kernel/debug/dri/0/name >"$out/drm-name.txt" 2>&1 || true
modetest -M msm -c -p -e >"$out/modetest.txt" 2>&1 || true

sha256sum /opt/tb371fc-kwin-dumbsync/bin/kwin_wayland \
    /opt/tb371fc-kwin-dumbsync/lib/libkwin.so.6.7.4 \
    >"$out/sha256.txt"
strings /opt/tb371fc-kwin-dumbsync/lib/libkwin.so.6.7.4 \
    | grep -F KWIN_DRM_DUMB_BUFFER_CPU_SYNC \
    >"$out/patch-marker.txt"

if [ -e /usr/local/bin/kwin_wayland ]; then
    cp /usr/local/bin/kwin_wayland "$out/oneshot-launcher.sh"
else
    printf 'one-shot launcher already removed\n' >"$out/oneshot-launcher-removed.txt"
fi

grep -iE 'DMA_BUF_IOCTL_SYNC|dumb buffer|drm|dsi|sde|kgsl|iommu|fault|error' \
    "$out/plasma.log" "$out/dmesg.txt" >"$out/relevant-errors.txt" || true

tar -C /var/tmp -czf "${out}.tar.gz" "$(basename "$out")"
printf '%s\n' "${out}.tar.gz"
