#!/usr/bin/env bash
# R193: hardware watchdog for remote tests - watchdog core + Qualcomm APSS WDT as modules for the
# R191 kernel (build dir r190). systemd pets /dev/watchdog0; a hard hang then resets the tablet
# (bootloader -> recovery_b console -> autoboot of the flashed release) instead of hanging forever.
set -euo pipefail
src=/root/tb371fc/linux-6.12-donor-r118; out=/root/tb371fc/build-6.12-r190
pkg=/mnt/d/TB371FC-builds/r193-watchdog; mkdir -p "$pkg"; rm -f "$pkg"/*.ko
cp "$out/Module.symvers" "$pkg/Module.symvers.before"; cp "$out/.config" "$pkg/config.before"
cd "$src"
scripts/config --file "$out/.config" -e WATCHDOG -m WATCHDOG_CORE -m QCOM_WDT -d WATCHDOG_HANDLE_BOOT_ENABLED
make O="$out" ARCH=arm64 LLVM=-18 olddefconfig >/dev/null
diff <(grep -v "^#" "$pkg/config.before" | sort) <(grep -v "^#" "$out/.config" | sort) || true
make O="$out" ARCH=arm64 LLVM=-18 -j"$(nproc)" Image modules > "$pkg/build.log" 2>&1 || { grep error "$pkg/build.log" | head; exit 1; }
cmp -s "$out/arch/arm64/boot/Image" /mnt/d/TB371FC-builds/r191-kernel/Image && echo "Image unchanged" || echo "IMAGE CHANGED"
join <(awk '{print $2, $1}' "$pkg/Module.symvers.before" | sort) <(awk '{print $2, $1}' "$out/Module.symvers" | sort) | awk '$2!=$3' | wc -l
cp "$out/drivers/watchdog/watchdog.ko" "$out/drivers/watchdog/qcom-wdt.ko" "$pkg/"
for k in "$pkg"/*.ko; do echo "$(basename $k): $(modinfo -F depends $k) $(modinfo -F vermagic $k | cut -d' ' -f1)"; done
