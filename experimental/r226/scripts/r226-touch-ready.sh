#!/bin/sh
set -eu
# Run only in the candidate, AFTER the native panel and desktop have started.
grep -qw tb371fc.r226 /proc/cmdline
test -e /dev/dri/by-path/platform-ae01000.display-controller-card
test -d /sys/bus/spi/drivers/NVT-ts-spi/spi14.0
sleep 2
insmod /run/r226/r225-touch-pm.ko
rmmod r225_touch_pm
echo 'R226 touch PM cycle completed; verify real touch input and visible desktop'
