#!/bin/sh
# Runtime-only Plasma Shell acceleration test for the V56 vendor kernel.
# KWin remains on the proven software renderer; only the Wayland client shell
# uses Turnip through Mesa's software WSI blit bridge.
set -eu

icd=/opt/tb371fc-mesa-kgsl-26.1.7/share/vulkan/icd.d/freedreno_icd.aarch64.json
mesa=/opt/tb371fc-mesa-zink-patched
log=/var/log/tb371fc-plasmashell-turnip.log

case "$(uname -r)" in
	4.19.157-perf-v56*) ;;
	*) echo 'Unsupported kernel for the V56 Turnip profile.' >&2; exit 2 ;;
esac

[ -s "$icd" ] || { echo "Missing Turnip ICD: $icd" >&2; exit 3; }
[ -c /dev/kgsl-3d0 ] || { echo 'Missing /dev/kgsl-3d0.' >&2; exit 4; }
[ -r "$mesa/lib/libgallium-26.1.7.so" ] || { echo "Missing patched Zink Mesa: $mesa" >&2; exit 8; }

kwin_pid=$(pgrep -o -x kwin_wayland 2>/dev/null || true)
[ -n "$kwin_pid" ] || { echo 'KWin is not running.' >&2; exit 5; }

dbus_address=$(tr '\0' '\n' <"/proc/$kwin_pid/environ" |
	sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p' | head -n 1)
case "$dbus_address" in
	unix:*) ;;
	*) echo 'KWin session D-Bus address was not found.' >&2; exit 6 ;;
esac

pkill -x plasmashell 2>/dev/null || true
for _ in 1 2 3 4 5; do
	pgrep -x plasmashell >/dev/null 2>&1 || break
	sleep 1
done
pkill -9 -x plasmashell 2>/dev/null || true

export HOME=/root USER=root LOGNAME=root
export DBUS_SESSION_BUS_ADDRESS="$dbus_address"
export XDG_RUNTIME_DIR=/run/user/0
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=KDE
export WAYLAND_DISPLAY=wayland-0
export QT_QPA_PLATFORM=wayland
export QT_SCALE_FACTOR=1
unset LIBGL_ALWAYS_SOFTWARE QT_QUICK_BACKEND
export QSG_RHI_BACKEND=opengl
export TB371FC_ZINK_KGSL_ALLOW_UNMATCHED=1
export LIBGL_DRIVERS_PATH="$mesa/lib/dri"
export LD_LIBRARY_PATH="$mesa/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export VK_ICD_FILENAMES="$icd"
export VK_DRIVER_FILES="$icd"
export MESA_LOADER_DRIVER_OVERRIDE=zink
export GALLIUM_DRIVER=zink
export TU_DEBUG=noconform
export MESA_VK_WSI_DEBUG=sw

echo "=== $(date -Iseconds 2>/dev/null || date) ===" >>"$log"
nohup /usr/bin/plasmashell >>"$log" 2>&1 &
shell_pid=$!
echo "$shell_pid" >/run/tb371fc-plasmashell-turnip.pid

sleep 12
if ! kill -0 "$shell_pid" 2>/dev/null; then
	echo 'Turnip plasmashell exited during startup.' >&2
	exit 7
fi

echo "Turnip plasmashell is running as PID $shell_pid."
