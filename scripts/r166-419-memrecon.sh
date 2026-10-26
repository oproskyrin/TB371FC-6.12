#!/bin/sh
# R166 recon on the first-stage 4.19 console (read-only): what 4.19 reserves/assigns, so that the
# 6.12 memory map (built from 4.19 "System RAM" by kexec) can be checked for firmware-owned RAM.
bb=/run/tb371fc-rescue/busybox
uname -r; cat /proc/meminfo | head -3
echo "--- iomem top level"; grep -v "^ " /proc/iomem
echo "--- dmesg reserved/cma/hyp"; dmesg | grep -i -E "reserved mem|cma|Reserved memory|hyp_assign|secure|carveout|memblock|removed" | head -60
echo "--- DT reserved-memory nodes (4.19)"
for n in /proc/device-tree/reserved-memory/*/; do
  nm=$(basename $n); r=""; s=""; f=""
  [ -e $n/reg ] && r=$("$bb" od -An -tx4 $n/reg | tr -s ' ')
  [ -e $n/size ] && s=$("$bb" od -An -tx4 $n/size | tr -s ' ')
  [ -e $n/no-map ] && f="$f no-map"; [ -e $n/reusable ] && f="$f reusable"
  [ -e $n/alloc-ranges ] && f="$f alloc=$("$bb" od -An -tx4 $n/alloc-ranges | tr -s ' ')"
  echo "$nm reg=[$r] size=[$s]$f"
done
