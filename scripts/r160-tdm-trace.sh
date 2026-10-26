#!/bin/sh
# R160: verbose qdsp6 debug; A) open/refine only (BE startup sets PRI_TDM clock), B) 1 s zeros.
# Run while the PC streams /dev/kmsg. May hang the system.
mount -t debugfs none /sys/kernel/debug 2>/dev/null
# an oops must not escalate to panic (CONFIG_PANIC_ON_OOPS=y; panic reboot hangs this board)
echo 0 > /proc/sys/kernel/panic_on_oops; echo "panic_on_oops=$(cat /proc/sys/kernel/panic_on_oops)"
for f in q6afe.c q6afe-dai.c q6afe-clocks.c q6asm.c q6asm-dai.c q6adm.c q6routing.c apr.c; do
  echo "file $f +p" > /sys/kernel/debug/dynamic_debug/control 2>/dev/null || echo "no dyndbg for $f"
done
amixer -c 0 cset name='PRIMARY_TDM_RX_0 Audio Mixer MultiMedia1' 1 | tail -1
echo "== TRACE A: open/refine" > /dev/kmsg; sleep 2
timeout 10 aplay -D hw:0,0 --dump-hw-params -f S16_LE -r 48000 -c 2 -d 1 /dev/null 2>&1 | head -3
echo "== TRACE A done" > /dev/kmsg; sleep 3
echo "== TRACE B: play zeros" > /dev/kmsg; sleep 2
timeout 10 aplay -D hw:0,0 -f S16_LE -r 48000 -c 2 -d 1 /dev/zero 2>&1 | head -3
echo "== TRACE B done" > /dev/kmsg; sleep 2
dmesg | sed -n '/TRACE A/,$p' | head -120
