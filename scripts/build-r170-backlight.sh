#!/usr/bin/env bash
# R170: TB371FC dual KTZ8866 backlight (backport + keep bootloader level) as an external module.
set -euo pipefail
p="$(cd "$(dirname "$0")/.." && pwd)"
src=/root/tb371fc/linux-6.12-donor-r118; out=/root/tb371fc/build-6.12-r159-audio
pkg=/mnt/d/TB371FC-builds/r170-backlight; mkdir -p "$pkg"
m=/root/tb371fc/r170-ktz8866; rm -rf "$m"; mkdir -p "$m"
cp "$p/scripts/r170-backlight/tb371fc-ktz8866.c" "$src/drivers/video/backlight/backlight.c" "$m/"
cat > "$m/Kbuild" <<'K'
obj-m += backlight.o tb371fc-ktz8866.o
# the kernel config has BACKLIGHT_CLASS_DEVICE off; build the class core as a module here
ccflags-y += -DCONFIG_BACKLIGHT_CLASS_DEVICE_MODULE=1
K
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 M="$m" modules > "$pkg/ktz-build.log" 2>&1 || { grep -E "error|warning" "$pkg/ktz-build.log" | head; exit 1; }
grep -i warning "$pkg/ktz-build.log" || true
modinfo -F vermagic "$m/tb371fc-ktz8866.ko"; modinfo -F alias "$m/tb371fc-ktz8866.ko" | head -2
cp "$m/tb371fc-ktz8866.ko" "$m/backlight.ko" "$pkg/"; sha256sum "$pkg/tb371fc-ktz8866.ko" "$pkg/backlight.ko"
