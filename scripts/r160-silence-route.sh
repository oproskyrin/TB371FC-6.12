#!/bin/sh
# R160 live: route MultiMedia1 -> PRIMARY_TDM_RX_0 and play 2 s of zeros (no amplifiers, pins not muxed).
amixer -c 0 cset name='PRIMARY_TDM_RX_0 Audio Mixer MultiMedia1' 1 | tail -1
fuser -v /dev/snd/* 2>&1 | head -5
echo "== routed silence playback" > /dev/kmsg
timeout 15 aplay -D hw:0,0 -f S16_LE -r 48000 -c 2 -d 2 /dev/zero; echo "aplay rc=$?"
dmesg | sed -n '/routed silence playback/,$p' | tail -20
for r in /sys/class/remoteproc/remoteproc*; do echo "$(cat $r/name) $(cat $r/state)"; done
