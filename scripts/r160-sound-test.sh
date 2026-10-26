#!/bin/sh
# R160 stage 2 (on the tablet): ADSP + APR services + ALSA card with PRI_TDM_RX_0 backend and a
# placeholder codec. TFA9894 stay disabled, TDM pins are not muxed. Plays 2 s of zeros only.
set -u
root=/run/r159-modroot; kr=$(uname -r)
mkdir -p $root; tar -xzf /run/r159-modroot.tar.gz -C $root 2>/dev/null
mkdir -p $root/lib/modules/$kr/extra; tar -xzf /run/r160-extra.tar.gz -C $root/lib/modules/$kr/extra
depmod -b $root $kr
cat /proc/sys/kernel/random/boot_id; echo "kernel=$kr"
mp() { echo "== modprobe $*" > /dev/kmsg; timeout 60 modprobe -d $root "$@"; echo "modprobe $* rc=$?"; }
mp clk-rpmh
mp qcom_q6v5_pas
for i in $(seq 1 40); do r=$(grep -l 17300000 /sys/class/remoteproc/remoteproc*/name 2>/dev/null | head -1); [ -n "$r" ] && grep -q running "${r%/name}/state" && break; sleep 1; done
mp apr; mp qcom_pd_mapper
for i in $(seq 1 30); do [ -e /sys/bus/aprbus/devices/aprsvc:service:4:8 ] && break; sleep 1; done
ls /sys/bus/aprbus/devices/ | tr '\n' ' '; echo
for m in q6core q6afe q6afe-clocks q6afe-dai q6asm q6asm-dai q6adm q6routing snd-soc-spdif-tx snd-soc-tb371fc; do mp $m; done
for i in $(seq 1 20); do grep -q TB371FC /proc/asound/cards 2>/dev/null && break; sleep 1; done
cat /proc/asound/cards; ls /dev/snd | tr '\n' ' '; echo
cat /proc/asound/pcm 2>&1
c=$(sed -n 's/^ *\([0-9]*\) \[.*TB371FC.*/\1/p' /proc/asound/cards | head -1)
if [ -n "$c" ] && command -v amixer >/dev/null; then
  amixer -c $c controls | grep -c . ; amixer -c $c controls | grep -i "PRI_TDM_RX_0" | head -5
  amixer -c $c cset name='PRI_TDM_RX_0 Audio Mixer MultiMedia1' 1 | tail -1
  fuser -v /dev/snd/* 2>&1 | head
  echo "== silence playback" > /dev/kmsg
  timeout 15 aplay -D hw:$c,0 -f S16_LE -r 48000 -c 2 -d 2 /dev/zero; echo "aplay rc=$?"
fi
dmesg | grep -i -E "q6|afe|asm|tdm|snd|asoc|tb371fc|spdif|sound" | grep -v -E "initcall|calling" | tail -30
