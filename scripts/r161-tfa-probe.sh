#!/bin/sh
# R161: ADSP/APR/LPASS votes + TFA9894 x4 probe on i2c@884000 (container FW=$FW) + card. NO playback.
set -u
FW=${FW:-lenovo/tb371fc/tfa98xx_QS.cnt}  # GPIO1171 (TLMM 71) = 1 on 4.19 -> QS container
echo 0 > /proc/sys/kernel/panic_on_oops
root=/run/r159-modroot; kr=$(uname -r); x=$root/lib/modules/$kr/extra
mkdir -p $root; tar -xzf /run/r159-modroot.tar.gz -C $root 2>/dev/null
mkdir -p $x; tar -xzf /run/r161-extra.tar.gz -C $x 2>/dev/null
depmod -b $root $kr
cat /proc/sys/kernel/random/boot_id; echo "FW=${FW:-unset}"
mp() { timeout 60 modprobe -d $root "$@"; echo "modprobe $* rc=$?"; }
mp clk-rpmh; mp qcom_q6v5_pas
for i in $(seq 1 40); do r=$(grep -l 17300000 /sys/class/remoteproc/remoteproc*/name 2>/dev/null | head -1); [ -n "$r" ] && grep -q running "${r%/name}/state" && break; sleep 1; done
mp apr; mp qcom_pd_mapper
for i in $(seq 1 30); do [ -e /sys/bus/aprbus/devices/aprsvc:service:4:8 ] && break; sleep 1; done
for m in q6core q6afe q6afe-clocks; do mp $m; done
insmod $x/tb371fc-lpass-vote.ko; echo "insmod lpass-vote rc=$?"
for m in q6afe-dai q6asm q6adm q6routing q6asm-dai; do mp $m; done
echo "--- i2c15"; ls /sys/bus/i2c/devices/ | tr '\n' ' '; echo
mp snd-soc-tfa98xx fw_name=${FW:-lenovo/tb371fc/tfa98xx_unset.cnt}
sleep 3
for d in /sys/bus/i2c/devices/*-003[4-7]; do echo "$(basename $d) $(cat $d/name) driver=$(basename "$(readlink $d/driver)" 2>/dev/null)"; done
mp snd-soc-tb371fc
for i in $(seq 1 20); do grep -q TB371FC /proc/asound/cards 2>/dev/null && break; sleep 1; done
sleep 3
cat /proc/asound/cards
amixer -c 0 controls 2>/dev/null | grep -i -E "Primary|Secondary|tfa|Profile|Vstep|Cal" | head -20
dmesg | grep -i -E "tfa|990000|i2c15|R161|container|cnt|mtp" | grep -v -E "initcall|calling" | tail -40
