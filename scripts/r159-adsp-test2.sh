#!/bin/sh
# R159 stage 1b: provide RPMh clocks (xo) so the deferred remoteprocs can probe.
set -u
root=/run/r159-modroot
cat /proc/sys/kernel/random/boot_id
echo "== insmod clk-rpmh" > /dev/kmsg
insmod /run/clk-rpmh.ko; echo "insmod rc=$?"
for i in $(seq 1 40); do s=$(cat /sys/class/remoteproc/remoteproc*/state 2>/dev/null | tr '\n' ' '); case "$s" in *running*) break;; esac; sleep 1; done
for r in /sys/class/remoteproc/remoteproc*; do echo "$(basename $r): $(cat $r/name) state=$(cat $r/state) fw=$(cat $r/firmware)"; done
for m in q6core q6afe q6afe-clocks q6adm q6asm q6routing; do echo "== modprobe $m"; timeout 60 modprobe -d $root $m; echo "rc=$?"; done
sleep 3
ls /sys/bus/apr/devices/ 2>&1
cat /sys/kernel/debug/devices_deferred 2>/dev/null
dmesg | grep -i -E "remoteproc|adsp|cdsp|slpi|q6|apr|glink|sysmon|clk-rpmh|cpufreq|pcie" | tail -40
