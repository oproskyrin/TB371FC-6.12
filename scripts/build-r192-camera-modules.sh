#!/usr/bin/env bash
# R192: camera modules for the R191 kernel: camcc (SM8250), CCI, CAMSS, RPMh regulators, V4L2 CCI
# helpers and the project's S5K4H7 driver. Same build dir as R191; Module.symvers must not change.
set -euo pipefail
p="$(cd "$(dirname "$0")/.." && pwd)"
src=/root/tb371fc/linux-6.12-donor-r118; out=/root/tb371fc/build-6.12-r190
pkg=/mnt/d/TB371FC-builds/r192-camera; mkdir -p "$pkg"; rm -f "$pkg"/*.ko
cp /root/tb371fc/build-6.12-r190/Module.symvers "$pkg/Module.symvers.before"
rm -f "$src/drivers/media/i2c/Kconfig.rej" "$src/drivers/media/i2c/Makefile.rej" "$src/drivers/media/i2c/s5k4h7.c"
cd "$src"
scripts/config --file "$out/.config" -m SM_CAMCC_8250 -m I2C_QCOM_CCI -m VIDEO_QCOM_CAMSS -m V4L2_CCI_I2C -m REGULATOR_QCOM_RPMH
make O="$out" ARCH=arm64 LLVM=-18 olddefconfig >/dev/null
grep -E "^CONFIG_(SM_CAMCC_8250|I2C_QCOM_CCI|VIDEO_QCOM_CAMSS|V4L2_CCI_I2C|V4L2_CCI|REGULATOR_QCOM_RPMH)=" "$out/.config"
make O="$out" ARCH=arm64 LLVM=-18 -j"$(nproc)" modules > "$pkg/build.log" 2>&1 || { grep -E "error" "$pkg/build.log" | head -20; exit 1; }
join <(awk '{print $2, $1}' "$pkg/Module.symvers.before" | sort) <(awk '{print $2, $1}' "$out/Module.symvers" | sort) | awk '$2!=$3' > "$pkg/crc-changed.txt"
echo "changed CRCs: $(wc -l < "$pkg/crc-changed.txt")"
# S5K4H7: external module (the 7.1 Kconfig patch does not apply to 6.12)
m=/root/tb371fc/r192-s5k4h7; rm -rf "$m"; mkdir -p "$m"; cp "$p/mainline-port/drivers/media/i2c/s5k4h7.c" "$m/"
# 6.12 compat: devm_v4l2_sensor_clk_get() arrived later; plain devm_clk_get() is equivalent here
sed -i 's/devm_v4l2_sensor_clk_get(sensor->dev, NULL)/devm_clk_get(sensor->dev, NULL)/' "$m/s5k4h7.c"; grep -n "devm_clk_get" "$m/s5k4h7.c"
echo 'obj-m := s5k4h7.o' > "$m/Kbuild"
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 M="$m" modules > "$pkg/s5k4h7-build.log" 2>&1 || { grep -E "error|warning" "$pkg/s5k4h7-build.log" | head; exit 1; }
cp "$m/s5k4h7.ko" "$pkg/"
for m in drivers/clk/qcom/camcc-sm8250.ko drivers/i2c/busses/i2c-qcom-cci.ko drivers/media/platform/qcom/camss/qcom-camss.ko \
         drivers/media/v4l2-core/v4l2-cci.ko drivers/regulator/qcom-rpmh-regulator.ko; do
  [ -f "$out/$m" ] && cp "$out/$m" "$pkg/" || echo "missing $m"
done
for k in "$pkg"/*.ko; do echo "$(basename $k): $(modinfo -F depends $k)"; done
grep -E "warning:.*s5k4h7" "$pkg/build.log" | head -5 || true
