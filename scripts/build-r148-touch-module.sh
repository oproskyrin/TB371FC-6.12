#!/usr/bin/env bash
# R148: build the project nt36523 SPI touchscreen driver (patch 0002, written
# for 7.1) as an external module for the R130/R140/R147 kernel
# 6.12.30-tb371fc-r130-usb2-late+. Kernel tree and output are not modified.
set -euo pipefail
project="$(cd "$(dirname "$0")/.." && pwd)"
src=/root/tb371fc/linux-6.12-donor-r118
out=/root/tb371fc/build-6.12-r130-usb2-late
mod=/root/tb371fc/r148-nt36523-module
pkg=/mnt/d/TB371FC-builds/r148-touch
patch="$project/mainline-port/patches/0002-input-touchscreen-add-nt36523-spi-pen.patch"
test -s "$out/Module.symvers" -o -s "$out/vmlinux.symvers"
if [ "${1:-}" != --resume ]; then
    test ! -e "$mod"; test ! -e "$pkg"
    mkdir -p "$mod" "$pkg"
    work=$(mktemp -d)
    # Apply only the new driver files into an empty scratch tree.
    (cd "$work"; filterdiff -i '*/nt36523/*' "$patch" | patch -p1 --quiet)
    cp "$work"/drivers/input/touchscreen/nt36523/*.[ch] "$mod/"
    rm -rf "$work"
    cat > "$mod/Kbuild" <<'EOF'
obj-m += nt36523_ts.o
nt36523_ts-y := nt36xxx.o nt36xxx_fw_update.o
EOF
fi
make -C "$src" O="$out" ARCH=arm64 LLVM=-18 M="$mod" modules 2>&1 | tee "$pkg/build.log" | tail -25
test -s "$mod/nt36523_ts.ko"
cp "$mod/nt36523_ts.ko" "$pkg/"
modinfo "$pkg/nt36523_ts.ko" | grep -E "vermagic|alias|depends|firmware" | tee "$pkg/modinfo.txt"
test "$(modinfo -F vermagic "$pkg/nt36523_ts.ko")" = "$(modinfo -F vermagic /mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r130-usb2-late/dwc3-qcom.ko)"
(cd "$pkg"; sha256sum nt36523_ts.ko > SHA256SUMS; cat SHA256SUMS)
