#!/bin/sh
# R162: grow the RAM overlay and install Chromium + plasma-pa (KDE volume applet). RAM only.
set -u
mount -o remount,size=3G /run/r129/rw && df -h / | tail -1
pacman -Q plasma-pa chromium 2>&1
pacman -Sy --noconfirm 2>&1 | tail -4
pacman -S --needed --noconfirm plasma-pa chromium 2>&1 | tail -15
pacman -Q plasma-pa chromium 2>&1
df -h / | tail -1
