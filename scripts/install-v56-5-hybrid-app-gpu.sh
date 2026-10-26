#!/bin/sh
# Install the stable V56.5 split graphics profile from an authenticated root
# shell on the tablet. The caller stages files below /tmp/tb371fc-gpu first.
set -eu

src=/tmp/tb371fc-gpu
[ "$(id -u)" = 0 ]
[ -x "$src/tb371fc-hw-run" ]
[ -x "$src/tb371fc-chromium" ]

install -d -m 0755 /usr/local/bin /etc/tb371fc
install -m 0755 "$src/tb371fc-hw-run" /usr/local/bin/tb371fc-hw-run
install -m 0755 "$src/tb371fc-chromium" /usr/local/bin/tb371fc-chromium

# Full KWin acceleration is unsafe on the downstream 4.19 SDE/KGSL split:
# remove only its opt-in markers, preserving all recovery and desktop data.
rm -f /etc/tb371fc/enable-v56-hardware-gl \
	/etc/tb371fc/v56-hardware-gl-confirmed \
	/run/tb371fc-hw-commit

sync
echo 'TB371FC stable hybrid application GPU profile installed.'
