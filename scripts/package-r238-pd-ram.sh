#!/bin/bash
# Isolated RAM-only package. NEVER flashes, edits SD or installs rootfs units.
set -euo pipefail
p='/mnt/c/Users/Sailren/Documents/ChatGPT/linux lenovo'
base=/mnt/d/TB371FC-builds/r226-v2-timerfix
parts=/mnt/d/TB371FC-builds/r237-pd-integration
dest=${R238_DEST:-/mnt/d/TB371FC-builds/r238-pd-ram-test}
pd_modules=${R238_TCPM_DIR:-$parts}
test "$(sha256sum "$base/initramfs.cpio.gz" | cut -d' ' -f1)" = 0bcad91fa94af6ee794b85c52da12180709c729690a992864090981dc75f1219
work=$(mktemp -d /root/tb371fc/r238-initrd.XXXXXX)
cd "$work"
gzip -dc "$base/initramfs.cpio.gz" | cpio -id --quiet
cp "$parts/r203-usb-regulators.ko" r226/r203-usb-regulators.ko
mkdir r238
cp "$pd_modules/"{r233_pmic_tcpm,tcpm}.ko r238/
cp "$parts/r235-watchdog-only.ko" r238/
cp "${R238_PROBE_FILE:-$p/scripts/r237-pd-integration/probe-r238.sh}" r238/probe-r238.sh
if [ -n "${R238_TRACE_FILE:-}" ]; then
    cp "$R238_TRACE_FILE" r238/collect-tcpm.sh
    sh -n r238/collect-tcpm.sh
fi
chmod 0755 r238/probe-r238.sh
sha256sum r238/*.ko | sed 's@  r238/@  @' > r238/SHA256SUMS
python3 "$p/scripts/r237-pd-integration/prepare-initrd.py" "$work"
sh -n bin/boot-arch-r129-base
sh -n r238/probe-r238.sh
mkdir -p "$dest"
find . -print0 | sort -z | cpio --null -o -H newc -R 0:0 --quiet | gzip -9n > "$dest/initramfs.cpio.gz"
cp "$base/Image" "$dest/"
cp "$parts/board-PD-ONLY-NOT-BOOT-READY.dtb" "$dest/board.dtb"
d=$dest/board.dtb
python3 "$p/scripts/prepare-r238-cmdline.py" "$d" "$dest/cmdline.txt"
cd "$dest"
sha256sum Image board.dtb initramfs.cpio.gz cmdline.txt > SHA256SUMS
tar -czf r238-pd-ram-payload.tar.gz Image board.dtb initramfs.cpio.gz cmdline.txt SHA256SUMS
cat SHA256SUMS
echo "PRIVATE INITRD $work"
