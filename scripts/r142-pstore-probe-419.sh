#!/bin/sh
# Read-only: how does first-stage 4.19 see pstore/ramoops and reserved memory.
uname -r; cat /proc/sys/kernel/random/boot_id
echo "== pstore mount"; grep pstore /proc/mounts || echo "not mounted"
mkdir -p /run/pstore-ro; mount -t pstore -o ro pstore /run/pstore-ro 2>&1; ls -la /run/pstore-ro 2>&1
echo "== ramoops DT"; for d in $(find /proc/device-tree -iname '*ramoops*' -o -iname '*pstore*' 2>/dev/null); do echo "$d"; ls "$d"; for p in reg record-size console-size pmsg-size ftrace-size mem-type ecc-size; do [ -e "$d/$p" ] && echo "$p: $(od -An -tx4 --endian=big $d/$p 2>/dev/null || od -An -tx1 $d/$p)"; done; done
echo "== modules/params"; ls /sys/module | grep -i -E "ramoops|pstore"; for f in /sys/module/ramoops/parameters/*; do [ -e "$f" ] && echo "$f=$(cat $f)"; done
echo "== iomem"; grep -i -E "ramoops|pstore|reserved|b0000000" /proc/iomem | head -20
dmesg | grep -i -E "ramoops|pstore|persistent_ram" | head -20
