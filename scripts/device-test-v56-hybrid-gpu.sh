#!/bin/sh
set -u

LOG=/var/log/tb371fc-hybrid-gpu-test.log
TMP=/tmp/tb371fc-glmark2-wayland.log
export HOME=/root
export XDG_RUNTIME_DIR=/run/user/0
export WAYLAND_DISPLAY=wayland-0

exec >"$LOG" 2>&1
echo "=== TB371FC V56 hybrid GPU validation ==="
date -Iseconds 2>/dev/null || date
uname -a
echo "DSI_BEFORE=$(cat /sys/class/drm/card0-DSI-1/enabled 2>/dev/null || echo missing)"
echo "BUSY_BEFORE=$(cat /sys/class/kgsl/kgsl-3d0/gpubusy 2>/dev/null || echo missing)"

rm -f "$TMP"
/usr/local/bin/tb371fc-hw-run /usr/bin/glmark2-wayland --validate >"$TMP" 2>&1 &
test_pid=$!

gpu_fd_seen=no
i=0
while kill -0 "$test_pid" 2>/dev/null && [ "$i" -lt 100 ]; do
    if find "/proc/$test_pid/fd" -lname '*kgsl-3d0*' -print -quit 2>/dev/null | grep -q .; then
        gpu_fd_seen=yes
        break
    fi
    for child in $(cat "/proc/$test_pid/task/$test_pid/children" 2>/dev/null); do
        if find "/proc/$child/fd" -lname '*kgsl-3d0*' -print -quit 2>/dev/null | grep -q .; then
            gpu_fd_seen=yes
            break 2
        fi
    done
    i=$((i + 1))
    sleep 0.1
done

wait "$test_pid"
rc=$?

echo "GLMARK_RC=$rc"
echo "GLMARK_GPU_FD=$gpu_fd_seen"
grep -E 'GL_VENDOR|GL_RENDERER|GL_VERSION|Validation|Score' "$TMP" || true
echo "BUSY_AFTER=$(cat /sys/class/kgsl/kgsl-3d0/gpubusy 2>/dev/null || echo missing)"
echo "DSI_AFTER=$(cat /sys/class/drm/card0-DSI-1/enabled 2>/dev/null || echo missing)"

kwin_pid=$(pidof kwin_wayland 2>/dev/null | awk '{print $1}')
plasma_pid=$(pidof plasmashell 2>/dev/null | awk '{print $1}')
echo "KWIN_PID=${kwin_pid:-missing}"
echo "PLASMA_PID=${plasma_pid:-missing}"
if [ -n "${kwin_pid:-}" ] && find "/proc/$kwin_pid/fd" -lname '*kgsl-3d0*' -print -quit 2>/dev/null | grep -q .; then
    echo "KWIN_GPU_FD=yes"
else
    echo "KWIN_GPU_FD=no"
fi

echo "FAULTS_BEGIN"
dmesg | tail -n 400 | grep -Ei 'kgsl|gpu fault|iommu.*fault|smmu.*fault|adreno.*fault' | tail -n 40 || true
echo "FAULTS_END"
echo "=== result complete ==="

cat "$LOG"
exit "$rc"
