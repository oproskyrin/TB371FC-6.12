#!/bin/sh
# Load the gated r139_panel module (probe_stage=0: no hardware IO) via the panel stage.
set -eu
sh /run/r134/config/r137-native-stage.sh panel
cat /sys/module/r139_panel/parameters/probe_stage
ls -l /sys/class/drm
mkdir -p /run/r141; dmesg > /run/r141/dmesg-before-step6.txt
cat /sys/kernel/debug/pm_genpd/mmcx/perf_state
