#!/usr/bin/env bash
# R166: compare reserved-memory of the running DT (R165) with the Lenovo/Qualcomm 4.19 kona layout.
set -euo pipefail
echo "=== R165 DT reserved-memory (name base size)"
dtc -q -I dtb -O dts /mnt/d/TB371FC-builds/r165-cpufreq/board.dtb 2>/dev/null | awk '/reserved-memory \{/{f=1} f' | awk '
/^\t\t[a-z0-9_-]+@[0-9a-f]+ \{/ {name=$1}
/reg = </ && name {gsub(/[<>;]/,""); printf "%-34s %s %s %s %s\n", name, $3, $4, $5, $6; name=""}
/^\t\};/ {exit}'
echo "=== 4.19 kona.dtsi reserved-memory"
k=/root/tb371fc-lenovo-4.19/arch/arm64/boot/dts/vendor/qcom/kona.dtsi
awk '/reserved_memory: reserved-memory/{f=1} f' $k | awk '
/^\t\t[a-z0-9_]+: [a-z0-9_-]+@[0-9a-f]+ \{/ {name=$2}
/reg = </ && name {line=$0; gsub(/[<>;\t]/,"",line); sub(/reg = /,"",line); printf "%-34s %s\n", name, line; name=""}
/^\t\};/ {exit}'
