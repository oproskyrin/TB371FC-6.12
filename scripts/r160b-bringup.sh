#!/bin/sh
# R160b: ADSP + APR + LPASS votes + card (DT has q6asm dai@N). No playback here.
set -u
root=/run/r159-modroot; kr=$(uname -r)
mkdir -p $root; tar -xzf /run/r159-modroot.tar.gz -C $root 2>/dev/null
mkdir -p $root/lib/modules/$kr/extra; tar -xzf /run/r160b-extra.tar.gz -C $root/lib/modules/$kr/extra 2>/dev/null
depmod -b $root $kr
cat /proc/sys/kernel/random/boot_id
mp() { timeout 60 modprobe -d $root "$@"; echo "modprobe $* rc=$?"; }
mp clk-rpmh; mp qcom_q6v5_pas
for i in $(seq 1 40); do r=$(grep -l 17300000 /sys/class/remoteproc/remoteproc*/name 2>/dev/null | head -1); [ -n "$r" ] && grep -q running "${r%/name}/state" && break; sleep 1; done
mp apr; mp qcom_pd_mapper
for i in $(seq 1 30); do [ -e /sys/bus/aprbus/devices/aprsvc:service:4:8 ] && break; sleep 1; done
for m in q6core q6afe q6afe-clocks; do mp $m; done
insmod $root/lib/modules/$kr/extra/tb371fc-lpass-vote.ko; echo "insmod lpass-vote rc=$?"; dmesg | grep -i -E "lpass-vote|33c0000" | tail -3
for m in q6afe-dai q6asm q6adm q6routing snd-soc-spdif-tx; do mp $m; done
mp q6asm-dai
mp snd-soc-tb371fc
for i in $(seq 1 20); do grep -q TB371FC /proc/asound/cards 2>/dev/null && break; sleep 1; done
cat /proc/asound/cards
fuser -v /dev/snd/* 2>&1 | head -5
