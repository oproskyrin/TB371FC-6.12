#!/usr/bin/env bash
set -euo pipefail
project="$(cd "$(dirname "$0")/.." && pwd)"
base=/mnt/d/TB371FC-builds/r138-power-closure
pkg=/mnt/d/TB371FC-builds/r139-panel-gates
test ! -e "$pkg/initramfs.cpio.gz"
(cd "$pkg"; sha256sum -c SHA256SUMS)
(cd "$base"; sha256sum -c SHA256SUMS)
cp "$base/Image" "$base/board.dtb" "$pkg/"
panel=/soc/display-subsystem@ae00000/dsi@ae94000/panel@0
test "$(fdtget -t s "$pkg/board.dtb" "$panel" pinctrl-names)" = default
fdtput -t s "$pkg/board.dtb" "$panel" pinctrl-names r139-display
stage=$(mktemp -d /root/tb371fc/r139-initramfs.XXXXXX)
printf '%s\n' "$stage" > "$pkg/staging-path.txt"
(cd "$stage"; gzip -dc "$base/initramfs.cpio.gz" | cpio -idmu --quiet)
# Keep the established module filename, but use diagnostic r139_panel object.
cp "$pkg/r139_panel.ko" "$stage/r134-modules/panel-novatek-nt36523.ko"
cp "$project/scripts/r139-step.sh" "$stage/r134-config/"
chmod 0755 "$stage/r134-config/r139-step.sh"
(cd "$stage/r134-modules"; sha256sum *.ko) > "$stage/r134-config/r137-modules.sha256"
cmp "$stage/bin/boot-arch-r129-base" "$project/scripts/r129-overlay-arch-loader.sh"
test ! -e "$stage/r130-config/id_ed25519"
sh -n "$stage/r134-config/r139-step.sh"
(cd "$stage"; find . -print0 | sort -z | cpio --null -o --format=newc --owner=0:0 --quiet | gzip -9n) > "$pkg/initramfs.cpio.gz"
dtc -q -s -I dtb -O dts "$base/board.dtb" > "$pkg/baseline-r138.dts"
dtc -q -s -I dtb -O dts "$pkg/board.dtb" > "$pkg/candidate.dts"
diff -u "$pkg/baseline-r138.dts" "$pkg/candidate.dts" > "$pkg/dtb.diff" || test "$?" = 1
python3 "$project/scripts/audit-r137-display-power.py" "$pkg/board.dtb" --require-closure > "$pkg/power-audit.txt"
(cd "$pkg"; sha256sum Image board.dtb initramfs.cpio.gz r139_panel.c r139_panel.ko > SHA256SUMS; tar -czf r139-panel-gates-payload.tar.gz Image board.dtb initramfs.cpio.gz; cat SHA256SUMS)
