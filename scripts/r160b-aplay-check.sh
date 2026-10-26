#!/bin/sh
# R160b: 3 s of zeros through MM1 -> PRIMARY_TDM_RX_0 with aplay, then error scan.
cat /proc/sys/kernel/random/boot_id
timeout 20 aplay -D hw:0,0 -f S16_LE -r 48000 -c 2 -d 3 /dev/zero; echo "aplay rc=$?"
timeout 20 aplay -D hw:0,0 -f S16_LE -r 48000 -c 2 -d 1 /dev/zero; echo "aplay#2 rc=$?"
dmesg | grep -i -E "q6afe|q6asm|q6adm|q6routing|apr|tdm|afe|asoc|error|fail" | grep -v -E "initcall|calling|pinctrl|geni|autofs|msm-mdss|deferred|517" | tail -15
for r in /sys/class/remoteproc/remoteproc*; do echo "$(cat $r/name) $(cat $r/state)"; done
uptime
