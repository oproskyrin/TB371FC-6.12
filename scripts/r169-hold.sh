#!/bin/sh
# R169 (4.19 console): ask the autoboot helper to stay in the console.
touch /run/tb371fc-autoboot-hold
sleep 2
uname -r; tail -2 /run/tb371fc-autoboot.log 2>/dev/null; cat /run/tb371fc-autoboot/state 2>/dev/null
