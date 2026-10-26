#!/usr/bin/env bash
# R194: Qualcomm interconnect (RPMh BCM voter + SM8250 NoCs) as modules for the R191 kernel.
set -euo pipefail
src=/root/tb371fc/linux-6.12-donor-r118; out=/root/tb371fc/build-6.12-r190
pkg=/mnt/d/TB371FC-builds/r194-icc; mkdir -p "$pkg"; rm -f "$pkg"/*.ko
cp "$out/Module.symvers" "$pkg/Module.symvers.before"
cd "$src"
scripts/config --file "$out/.config" -m INTERCONNECT_QCOM -m INTERCONNECT_QCOM_BCM_VOTER -m INTERCONNECT_QCOM_RPMH -m INTERCONNECT_QCOM_SM8250
make O="$out" ARCH=arm64 LLVM=-18 olddefconfig >/dev/null
grep -E "^CONFIG_INTERCONNECT_QCOM" "$out/.config"
make O="$out" ARCH=arm64 LLVM=-18 -j"$(nproc)" modules > "$pkg/build.log" 2>&1 || { grep error "$pkg/build.log" | head; exit 1; }
join <(awk '{print $2, $1}' "$pkg/Module.symvers.before" | sort) <(awk '{print $2, $1}' "$out/Module.symvers" | sort) | awk '$2!=$3' | wc -l
find "$out/drivers/interconnect" -name "*.ko" -exec cp {} "$pkg/" \;
for k in "$pkg"/*.ko; do echo "$(basename $k): $(modinfo -F depends $k)"; done
