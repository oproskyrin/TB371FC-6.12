#!/bin/sh
# R160 live: replace q6asm-dai with the DT-less fallback build, then check the card and play 2 s of zeros.
set -u
cat /proc/sys/kernel/random/boot_id
rmmod q6asm-dai; echo "rmmod rc=$?"
echo "== insmod q6asm-dai fallback" > /dev/kmsg
insmod /run/q6asm-dai-fallback.ko; echo "insmod rc=$?"
for i in $(seq 1 20); do grep -q TB371FC /proc/asound/cards 2>/dev/null && break; sleep 1; done
cat /proc/asound/cards; ls /dev/snd | tr '\n' ' '; echo; cat /proc/asound/pcm 2>&1
c=$(sed -n 's/^ *\([0-9]*\) \[.*TB371FC.*/\1/p' /proc/asound/cards | head -1)
if [ -n "$c" ]; then
  echo "controls=$(amixer -c $c controls | grep -c .)"; amixer -c $c controls | grep -i "PRI_TDM_RX_0 Audio Mixer" | head -3
  amixer -c $c cset name='PRI_TDM_RX_0 Audio Mixer MultiMedia1' 1 | tail -1
  fuser -v /dev/snd/* 2>&1 | head
  echo "== silence playback" > /dev/kmsg
  timeout 15 aplay -v -D hw:$c,0 -f S16_LE -r 48000 -c 2 -d 2 /dev/zero 2>&1 | tail -8; echo "aplay done"
fi
dmesg | grep -i -E "q6|afe|asm|tdm|snd|asoc|tb371fc|spdif|sound|routing" | grep -v -E "initcall|calling|NVT" | tail -25
