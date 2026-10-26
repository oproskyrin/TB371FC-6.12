#!/bin/sh
# Hold a modeset and dump DPU plane/CRTC state and GEM iovas while it is active.
setsid sh -c 'sleep 90 | timeout 92 modetest -M msm -s 33@89:2944x1840-60 > /run/r144-modetest2.out 2>&1' > /dev/null 2>&1 &
sleep 6
d=/sys/kernel/debug/dri/1
cat $d/state | grep -v -E "^\s+(color|rotation|normalized|colorspace|self_refresh|max_requested|min_requested)" | head -120
echo "== gem"; cat $d/gem 2>/dev/null | head -20
echo "== fb"; cat $d/framebuffer 2>/dev/null | head -30
echo "== modetest"; head -8 /run/r144-modetest2.out
echo "== faults"; dmesg | grep "Unhandled context fault" | sed 's/.*iova=\(0x[0-9a-f]*\).*cbfrsynra=\(0x[0-9a-f]*\).*/\1 \2/' | sort | uniq -c | sort -rn | head -15
