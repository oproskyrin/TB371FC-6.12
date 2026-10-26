#!/usr/bin/env bash
# R187/R188 kernel: R179 kernel (headless GPU) + CONFIG_USER_NS + PID_NS (R188: Chromium namespace sandbox needs CLONE_NEWPID) (systemd service sandboxing, Chromium
# sandbox, Flatpak) + CONFIG_FUEL_GAUGE_MM8013=y (no out-of-tree module needed).
# Separate build dir; Module.symvers is compared with R179 so existing modules can be reused.
set -euo pipefail
src=/root/tb371fc/linux-6.12-donor-r118; old=/root/tb371fc/build-6.12-r159-audio; out=/root/tb371fc/build-6.12-r187
pkg=/mnt/d/TB371FC-builds/r188-kernel; mkdir -p "$pkg"
grep -q "tb371fc,headless-gpu" "$src/drivers/gpu/drm/msm/adreno/adreno_device.c"
[ -d "$out" ] || cp -a "$old" "$out"
cd "$src"
scripts/config --file "$out/.config" -e USER_NS -e PID_NS -d IPC_NS -d SYSVIPC -e FUEL_GAUGE_MM8013
make O="$out" ARCH=arm64 LLVM=-18 olddefconfig >/dev/null
grep -E "^CONFIG_(PID_NS|IPC_NS|SYSVIPC)=|^CONFIG_USER_NS=|^CONFIG_FUEL_GAUGE_MM8013=|^CONFIG_LOCALVERSION=" "$out/.config"
make O="$out" ARCH=arm64 LLVM=-18 -j"$(nproc)" Image modules > "$pkg/build.log" 2>&1 || { tail -30 "$pkg/build.log"; exit 1; }
cat "$out/include/config/kernel.release"
cp "$out/arch/arm64/boot/Image" "$pkg/Image"; sha256sum "$pkg/Image"
# symbol CRC comparison (exported symbols present in both builds)
join <(awk '{print $2, $1}' "$old/Module.symvers" | sort) <(awk '{print $2, $1}' "$out/Module.symvers" | sort) | awk '$2!=$3' > "$pkg/crc-changed.txt"
echo "changed CRCs: $(wc -l < "$pkg/crc-changed.txt")"; head -20 "$pkg/crc-changed.txt"
