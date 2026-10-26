#!/bin/sh
# R148: verify SPI master, then load the nt36523 touch module from /run.
cat /proc/sys/kernel/random/boot_id; nproc
echo "== spi"; ls /sys/bus/spi/devices/ 2>&1; ls -l /sys/bus/platform/devices/880000.spi/driver 2>&1
dmesg | grep -i -E "880000|spi|geni" | grep -v cpufreq | tail -8
echo "== gpio"; grep -E "gpio(40|41|42|43|56|68|82) " /sys/kernel/debug/gpio 2>/dev/null | head
echo "== load"
echo "$(sha256sum /run/nt36523_ts.ko)"
dmesg -C 2>/dev/null || true
timeout 60 insmod /run/nt36523_ts.ko; echo "insmod rc=$?"
sleep 8
dmesg | grep -v cpufreq | tail -40
echo "== input"; for d in /sys/class/input/input*; do echo "$(basename $d): $(cat $d/name)"; done
