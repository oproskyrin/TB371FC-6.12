#!/bin/sh
# R159 stage 1c: in-kernel PD mapper so APR sees avs/audio UP and registers q6 services.
set -u
cat /proc/sys/kernel/random/boot_id
echo "== insmod qcom_pd_mapper" > /dev/kmsg
insmod /run/qcom_pd_mapper.ko; echo "insmod rc=$?"
svc() { ls /sys/bus/aprbus/devices/ 2>/dev/null | tr '\n' ' '; }
for i in $(seq 1 20); do [ -n "$(svc)" ] && break; sleep 1; done
echo "aprbus: $(svc)"
if [ -z "$(svc)" ]; then
  echo "== restart ADSP" > /dev/kmsg; echo "restart ADSP"
  r=$(grep -l 17300000 /sys/class/remoteproc/remoteproc*/name | xargs dirname)
  echo stop > $r/state; sleep 2; echo start > $r/state
  for i in $(seq 1 30); do [ -n "$(svc)" ] && break; sleep 1; done
  echo "aprbus: $(svc)"
fi
for d in /sys/bus/aprbus/devices/*; do echo "$(basename $d) -> $(basename "$(readlink $d/driver)" 2>/dev/null)"; done
for r in /sys/class/remoteproc/remoteproc*; do echo "$(cat $r/name) state=$(cat $r/state)"; done
dmesg | grep -i -E "pd_mapper|pdr|apr|q6|afe|adsp|17300000" | grep -v -E "initcall|calling" | tail -25
