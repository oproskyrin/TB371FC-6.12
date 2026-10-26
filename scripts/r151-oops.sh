#!/bin/sh
dmesg > /run/r151-dmesg.txt
n=$(grep -n "Modules linked in" /run/r151-dmesg.txt | head -1 | cut -d: -f1)
[ -n "$n" ] && sed -n "$((n-25)),$((n+40))p" /run/r151-dmesg.txt
echo "== tail"; tail -15 /run/r151-dmesg.txt
ip -br link | grep wl
