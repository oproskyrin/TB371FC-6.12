#!/bin/sh
# Sole consumer of destructive TCPM debugfs log during trial. RAM-only, bounded.
set -eu
dir=/run/r238
test ! -e "$dir/tcpm-full.log"
test ! -e "$dir/trace-ready"
: > "$dir/tcpm-full.log"
: > "$dir/trace-ready"
n=0
while [ "$n" -lt 800 ]; do
    for log in /sys/kernel/debug/usb/tcpm-*/log; do
        [ -r "$log" ] || continue
        cat "$log" >> "$dir/tcpm-full.log" || exit 1
    done
    [ "$(wc -c < "$dir/tcpm-full.log")" -lt 1048576 ] || exit 0
    n=$((n+1)); sleep 0.1
done
