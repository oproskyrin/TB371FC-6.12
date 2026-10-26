#!/bin/sh
# R180 (first-stage 4.19 console): load the read-only display register dump module, print the dump.
uname -r
cat /sys/kernel/debug/dri/0/state 2>/dev/null | head -40
insmod /run/tb371fc-regdump.ko 2>&1 && dmesg | grep "TB371FC_REG" | sed 's/^\[[^]]*\] //' > /run/regdump-419.txt
rmmod tb371fc_regdump 2>/dev/null
wc -l /run/regdump-419.txt
cat /run/regdump-419.txt
