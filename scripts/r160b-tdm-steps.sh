#!/bin/sh
# R160: route MM1 -> PRIMARY_TDM_RX_0 and walk the PCM step by step (pcm-steps), zeros only.
# The PC streams /dev/kmsg; the last PCMSTEP marker shows the failing step.
echo 0 > /proc/sys/kernel/panic_on_oops
echo 10 > /proc/sys/kernel/printk_delay
p=/run/r159-modroot/lib/modules/$(uname -r)/extra/pcm-steps; chmod +x $p
amixer -c 0 cset name='PRIMARY_TDM_RX_0 Audio Mixer MultiMedia1' 1 | tail -1
$p /dev/snd/pcmC0D0p 3
echo 0 > /proc/sys/kernel/printk_delay
dmesg | sed -n '/PCMSTEP A/,$p' | grep -v -E '^ (SUBSYSTEM|DEVICE)=' | head -60
