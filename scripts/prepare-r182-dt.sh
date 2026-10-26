#!/usr/bin/env bash
# R182 DT: R180 native DT + DSI1 (bonded slave) clocked from DSI0's PHY, like Xiaomi pipa mainline DT
# and the vendor 4.19 state (PHY1 PLL off).
set -euo pipefail
src=/mnt/d/TB371FC-builds/r180-native/board.dtb; pkg=/mnt/d/TB371FC-builds/r182-native; mkdir -p "$pkg"; d=$pkg/board.dtb
test "$(sha256sum "$src" | cut -d' ' -f1)" = 39bdfe6fea799cf4823f1049e5f9f9e1da344f831afe594681d3be430ffd05ff
cp "$src" "$d"
m=/soc@0/display-subsystem@ae00000
ph0=$(fdtget -t x "$d" $m/phy@ae94400 phandle)
fdtput -t x "$d" $m/dsi@ae96000 assigned-clock-parents $ph0 0 $ph0 1
fdtget -t x "$d" $m/dsi@ae96000 assigned-clock-parents; sha256sum "$d"
