#!/bin/sh
# R166 (4.19, read-only): classify every 1 MiB of RAM 0x80000000..0x280000000 by kpageflags of its
# first two pages; print collapsed runs (MiB numbers = physical address >> 20).
bb=/run/tb371fc-rescue/busybox
for seg in 0 1 2 3 4 5 6 7; do
  s=$((0x80000 + seg*0x40000)); mb0=$(( (0x80000 + seg*0x40000) / 256 ))
  "$bb" dd if=/proc/kpageflags bs=8 skip=$s count=$((0x40000)) 2>/dev/null | "$bb" od -An -tx8 -w8 -v | "$bb" awk -v m=$mb0 'NR%256==1{h=$1} NR%256==2{printf "%d %s.%s\n", m+int((NR-2)/256), h, $1}'
done | "$bb" awk '{ if ($2!=prev) { if (n) printf "MB 0x%x-0x%x (%d MiB) %s\n", first, last, n, prev; prev=$2; first=$1; n=0 } last=$1; n++ } END { printf "MB 0x%x-0x%x (%d MiB) %s\n", first, last, n, prev }' > /run/kpagemap.txt
wc -l < /run/kpagemap.txt
grep -n "0000000000008000.0000000000010000\|0000000000008080.0000000000010080" /run/kpagemap.txt | head -60
