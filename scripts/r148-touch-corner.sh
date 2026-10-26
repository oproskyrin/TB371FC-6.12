#!/bin/sh
# Capture raw multitouch X/Y (ABS_MT_POSITION_X=0x35, _Y=0x36) for 8 s; print averages.
e=$(grep -l NVTCapacitiveTouchScreen /sys/class/input/event*/device/name | head -1 | sed 's#/device/name##; s#.*/##')
timeout 12 cat /dev/input/$e > /run/touch-corner.bin
od -An -v -tu2 -w24 /run/touch-corner.bin | awk '
  { type=$9; code=$10; val=$11 + $12*65536; if (type==3 && code==53) {sx+=val; nx++} if (type==3 && code==54) {sy+=val; ny++} }
  END { if (nx) printf "X avg=%d (n=%d)  ", sx/nx, nx; if (ny) printf "Y avg=%d (n=%d)", sy/ny, ny; print "" }'
