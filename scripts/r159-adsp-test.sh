#!/bin/sh
# R159 stage 1 (on the tablet): boot the ADSP and its APR/QDSP6 services. No sound
# card, no speaker amplifiers. Modules come from /run (RAM only).
set -u
root=/run/r159-modroot
mkdir -p $root; tar -xzf /run/r159-modroot.tar.gz -C $root
kr=$(uname -r); echo "kernel=$kr"
mp() { echo "== modprobe $*" > /dev/kmsg; echo "== modprobe $*"; timeout 60 modprobe -d $root "$@"; echo "rc=$?"; }
mp qcom_q6v5_pas
for i in $(seq 1 30); do s=$(cat /sys/class/remoteproc/remoteproc*/state 2>/dev/null | tr '\n' ' '); case "$s" in *running*) break;; esac; sleep 1; done
for r in /sys/class/remoteproc/remoteproc*; do echo "$(basename $r): $(cat $r/name) state=$(cat $r/state) fw=$(cat $r/firmware)"; done
mp apr
mp snd-q6core 2>/dev/null || mp q6core
sleep 3
ls /sys/bus/apr/devices/ 2>&1
dmesg | grep -i -E "remoteproc|adsp|q6v5|apr|q6core|qcom_q6|glink|sysmon|lpass" | tail -30
