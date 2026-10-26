#!/bin/sh
# R162: first audible test. Route MM1 -> PRIMARY_TDM_RX_0 and play /run/tone.wav
# (440 Hz, -40 dBFS, one channel, 2 s). Logs TFA start/stop and errors.
echo 0 > /proc/sys/kernel/panic_on_oops
amixer -c 0 cset name='PRIMARY_TDM_RX_0 Audio Mixer MultiMedia1' 1 | tail -1
echo "== R162 tone start" > /dev/kmsg
timeout 15 aplay -D hw:0,0 /run/tone.wav; echo "aplay rc=$?"
sleep 1
echo "== R162 tone done" > /dev/kmsg
dmesg | sed -n '/R162 tone start/,$p' | grep -v -E "^ (SUBSYSTEM|DEVICE)=|initcall|calling|cpufreq|pcie" | head -50
echo "MTP guard hits: $(dmesg | grep -c 'R161 MTP guard')"
