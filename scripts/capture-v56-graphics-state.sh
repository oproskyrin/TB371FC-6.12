#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Read-only graphics snapshot for the downstream TB371FC launch kernel.
set -u

section() {
	printf '\n===== %s =====\n' "$1"
}

read_file() {
	path=$1
	if [ -r "$path" ]; then
		printf '%s: ' "$path"
		cat "$path" 2>/dev/null || true
	fi
}

section identity
date -Ins 2>/dev/null || date
uname -a
cat /proc/cmdline

section framebuffer
for path in \
	/sys/class/graphics/fb0/name \
	/sys/class/graphics/fb0/mode \
	/sys/class/graphics/fb0/modes \
	/sys/class/graphics/fb0/virtual_size \
	/sys/class/graphics/fb0/bits_per_pixel \
	/sys/class/graphics/fb0/stride \
	/sys/class/graphics/fb0/blank; do
	read_file "$path"
done
ls -la /dev/fb* /sys/class/graphics 2>/dev/null || true
grep -i -E 'framebuffer|fb0|simplefb|mdp|dsi|sde|gpu' /proc/iomem 2>/dev/null || true

section drm
find /sys/class/drm -maxdepth 3 -type f -print 2>/dev/null | sort
for path in /sys/class/drm/*/status /sys/class/drm/*/modes /sys/class/drm/*/enabled; do
	read_file "$path"
done
ls -la /dev/dri 2>/dev/null || true

section display-device-tree
find /sys/firmware/devicetree/base -type d \
	\( -iname '*dsi*' -o -iname '*panel*' -o -iname '*display*' \
	-o -iname '*mdss*' -o -iname '*gpu*' \) -print 2>/dev/null | sort

section regulators
for regulator in /sys/class/regulator/regulator.*; do
	[ -d "$regulator" ] || continue
	name=$(cat "$regulator/name" 2>/dev/null || true)
	case "$name" in
		*disp*|*dsi*|*lcd*|*mdp*|*gpu*|*sde*|*avdd*|*vddio*|*ktz*)
			printf '%s name=%s state=%s voltage_uv=%s\n' \
				"$regulator" "$name" \
				"$(cat "$regulator/state" 2>/dev/null || true)" \
				"$(cat "$regulator/microvolts" 2>/dev/null || true)"
			;;
	esac
done

section graphics-processes
ps -ef 2>/dev/null | grep -E 'Xorg|kwin|plasmashell|sddm|weston' | grep -v grep || true

section renderer
if command -v glxinfo >/dev/null 2>&1; then
	DISPLAY=:0 XAUTHORITY=/root/.Xauthority glxinfo -B 2>&1 || true
else
	echo 'glxinfo unavailable'
fi
if command -v eglinfo >/dev/null 2>&1; then
	DISPLAY=:0 XAUTHORITY=/root/.Xauthority eglinfo -B 2>&1 || true
else
	echo 'eglinfo unavailable'
fi

section loaded-modules
grep -E '(^| )(drm|msm|sde|adreno|gpu|panel|fb|wlan)' /proc/modules 2>/dev/null || true

section display-dmesg
dmesg | grep -i -E 'drm|sde|dsi|mdss|simple.?frame|fb0|adreno|gpu|panel|backlight|ktz|splash|display|iommu' || true

section snapshot-complete
echo TB371FC_V56_GRAPHICS_SNAPSHOT_COMPLETE
