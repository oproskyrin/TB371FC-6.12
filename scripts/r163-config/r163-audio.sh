#!/bin/sh
# R163: bring up internal speakers at boot: ADSP (clk-rpmh, PAS), APR + PD mapper, q6 services,
# LPASS HW votes, 4x TFA9894 (QS container, MTP writes blocked in the driver), TB371FC card,
# MM1 -> PRIMARY_TDM_RX_0 route, then restart the user's PipeWire. Never blocks the boot.
set -u
exec >>/run/r163-audio.log 2>&1
echo "R163 audio: start uptime=$(cut -d' ' -f1 /proc/uptime)"
root=/run/r163-modroot; kr=$(uname -r)
mkdir -p $root; tar -xzf /run/r130/config/r163-modroot.tar.gz -C $root
mp() { timeout 60 modprobe -d $root "$@" || echo "R163 audio: modprobe $* rc=$?"; }
# R164: thermal sensors first (DT thermal zones + CPU cooling via cpufreq-hw, which probes once clk-rpmh provides xo)
mp qcom_tsens
# R167: throttle from 75 C instead of 85/90 C (cooler tablet; critical trips unchanged)
sh /run/r130/config/r166-thermal-tune.sh
mp clk-rpmh; mp qcom_q6v5_pas
for i in $(seq 1 40); do r=$(grep -l 17300000 /sys/class/remoteproc/remoteproc*/name 2>/dev/null | head -1); [ -n "$r" ] && grep -q running "${r%/name}/state" && break; sleep 1; done
mp apr; mp qcom_pd_mapper
for i in $(seq 1 30); do [ -e /sys/bus/aprbus/devices/aprsvc:service:4:8 ] && break; sleep 1; done
for m in q6core q6afe q6afe-clocks tb371fc-lpass-vote q6afe-dai q6asm q6adm q6routing q6asm-dai; do mp $m; done
mp snd-soc-tfa98xx fw_name=lenovo/tb371fc/tfa98xx_QS.cnt
mp snd-soc-tb371fc
for i in $(seq 1 30); do grep -q TB371FC /proc/asound/cards 2>/dev/null && break; sleep 1; done
amixer -c 0 cset name='PRIMARY_TDM_RX_0 Audio Mixer MultiMedia1' 1 >/dev/null || echo "R163 audio: route failed"
grep TB371FC /proc/asound/cards || { echo "R163 audio: no card"; exit 0; }
# PipeWire opens hw:0,0 at start; restart it now that the card exists, then set a safe volume.
for i in $(seq 1 120); do [ -S /run/user/1000/pipewire-0 ] && break; sleep 2; done
U() { runuser -u alarm -- env XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus "$@"; }
U systemctl --user restart pipewire pipewire-pulse wireplumber
sleep 4
U pactl set-default-sink tb371fc-speakers; U pactl set-sink-volume tb371fc-speakers 35%
echo "R163 audio: done uptime=$(cut -d' ' -f1 /proc/uptime)"
