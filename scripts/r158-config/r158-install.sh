#!/bin/sh
# R158: suspend/s2idle is not supported on this port; KDE's idle suspend (~15 min)
# froze the tablet with a dark screen. Block all sleep states for this boot (RAM only).
systemctl mask --runtime sleep.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
echo 'R158: sleep/suspend masked for this boot'
