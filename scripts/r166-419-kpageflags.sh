#!/bin/sh
# R166 (4.19, read-only): page flags around the RAM that hangs 6.12 (0x1d0c00000..), 4 KiB pages.
bb=/run/tb371fc-rescue/busybox
ls -l /proc/kpageflags /proc/kpagecount 2>&1
# pfn 0x1d0b00 .. 0x1d0f00 (16 MiB around the start), print distinct flag words with run lengths
start=$((0x1d0b00)); count=1024
"$bb" dd if=/proc/kpageflags bs=8 skip=$start count=$count 2>/dev/null | "$bb" od -An -tx8 -w8 -v | "$bb" awk -v s=$start '{ if ($1!=prev) { if (n) printf "pfn %x +%d flags %s\n", ps, n, prev; prev=$1; ps=s+NR-1; n=0 } n++ } END { printf "pfn %x +%d flags %s\n", ps, n, prev }'
"$bb" dd if=/proc/kpagecount bs=8 skip=$start count=$count 2>/dev/null | "$bb" od -An -tu8 -w8 -v | "$bb" sort | "$bb" uniq -c | head
