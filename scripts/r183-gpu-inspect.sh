#!/bin/sh
set -u
uname -a
cat /proc/sys/kernel/random/boot_id /proc/uptime
ls -l /dev/dri /dev/dri/by-path
systemctl cat r149-plasma.service
command -v eglinfo glxinfo glmark2 glmark2-es2-wayland glmark2-wayland vulkaninfo qdbus6 gcc pkg-config
runuser -u alarm -- env -u LIBGL_ALWAYS_SOFTWARE EGL_PLATFORM=surfaceless timeout 25 eglinfo -B 2>&1
dmesg | grep -iE 'adreno|gmu|firmware|fault|oops|hang' | tail -35
ls /run/user/1000/bus /run/user/1000/wayland-0
find /opt -maxdepth 2 -name '*kwin*'
systemctl is-active r149-plasma.service NetworkManager bluetooth r163-audio.service
