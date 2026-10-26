#!/bin/sh
set -u

export HOME=/root
export XDG_RUNTIME_DIR=/run/user/0
export WAYLAND_DISPLAY=wayland-0
LOG=/tmp/tb371fc-chromium-hw.log

pkill -TERM -x chromium 2>/dev/null || true
sleep 2
rm -f "$LOG"
nohup /usr/local/bin/tb371fc-chromium about:blank >"$LOG" 2>&1 &
launch_pid=$!
echo "CHROMIUM_LAUNCH_PID=$launch_pid"

gpu_fd_seen=no
i=0
while [ "$i" -lt 150 ]; do
    for p in $(pgrep chromium 2>/dev/null); do
        if find "/proc/$p/fd" -lname '*kgsl-3d0*' -print -quit 2>/dev/null | grep -q .; then
            gpu_fd_seen=yes
            echo "CHROMIUM_GPU_PID=$p"
            break 2
        fi
    done
    i=$((i + 1))
    sleep 0.1
done

echo "CHROMIUM_GPU_FD=$gpu_fd_seen"
echo "DSI=$(cat /sys/class/drm/card0-DSI-1/enabled 2>/dev/null || echo missing)"
echo "PROCESSES_BEGIN"
pgrep -a chromium 2>/dev/null | head -n 30 || true
echo "PROCESSES_END"
echo "LOG_BEGIN"
tail -n 100 "$LOG" 2>/dev/null || true
echo "LOG_END"
echo "FAULTS_BEGIN"
dmesg | tail -n 300 | grep -Ei 'gpu fault|iommu.*fault|smmu.*fault|kgsl.*fault' | tail -n 30 || true
echo "FAULTS_END"

[ "$gpu_fd_seen" = yes ]
