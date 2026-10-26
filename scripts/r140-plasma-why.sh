#!/bin/sh
date
journalctl -b --no-pager -o short-monotonic | grep -v xdg-desktop-portal | awk '/R140 Plasma software test/{n++} n>=2' | grep -v "Activating service" | head -70
