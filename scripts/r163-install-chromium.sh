#!/bin/sh
# R163 layer build step 1 (RAM): install Chromium + deps only; no system upgrade.
set -u
mount -o remount,size=3G /run/r129/rw
pacman -Sy --noconfirm 2>&1 | tail -2
pacman -S --needed --noconfirm chromium 2>&1 | grep -E "upgraded|installed|error|warning" | head; pacman -Q chromium
grep -E "\[ALPM\] upgraded" /var/log/pacman.log | tail -5
pacman -Scc --noconfirm >/dev/null 2>&1; rm -rf /var/cache/pacman/pkg/*
du -sh /run/r129/rw/upper; df -h / | tail -1
