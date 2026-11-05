#!/bin/bash
# Offline PD-only integration manifest. NOT a bootable release.
set -euo pipefail
dest=/mnt/d/TB371FC-builds/r237-pd-integration
base=/mnt/d/TB371FC-builds/r234-fsa-bus/board.dtb
mkdir -p "$dest"
test "$(sha256sum "$base" | cut -d' ' -f1)" = 522b754fc5e04d89b0b8bdc78d7881ea3fa03d992dbfdee65f5c90531d6c7023
cp "$base" "$dest/board-PD-ONLY-NOT-BOOT-READY.dtb"
d=$dest/board-PD-ONLY-NOT-BOOT-READY.dtb
port=/soc@0/spmi@c440000/pmic@2/typec@1500
conn=$port/connector
reg=/soc@0/rsc@18200000/regulators-0
test "$(fdtget -t x "$d" "$reg/ldo2" regulator-min-microvolt)" = 2ee000
test "$(fdtget -t x "$d" "$reg/ldo2" regulator-max-microvolt)" = 2ee000
fdtput "$d" "$reg" tb371fc,r237-pd-ldo2
fdtput "$d" "$port" tb371fc,r236-current-limit-test
fdtput "$d" "$port" tb371fc,r235-watchdog-only-test
fdtput -d "$d" "$port" vdd-vbus-supply
fdtput -t s "$d" "$conn" power-role sink
fdtput -t s "$d" "$conn" data-role device
fdtput -d "$d" "$conn" source-pdos
# Fixed5V 1.5A + USB communications, no power/data role-swap flags.
fdtput -t x "$d" "$conn" sink-pdos 04019096
fdtput -t i "$d" "$conn" op-sink-microwatt 2500000
# First negotiate PD without donor NB7/FSA/DP graphs. Data and DP test later.
fdtput -r "$d" "$conn/ports"
fdtput -r "$d" "$conn/altmodes"
fdtput -t s "$d" /chosen tb371fc,r237-test pd-only-integration-draft
args=$(fdtget -t s "$d" /chosen bootargs)
args="$args tb371fc.r237 systemd.mask=r231-charge-keepalive.service"
fdtput -t s "$d" /chosen bootargs "$args"
printf '%s\n' "$args" > "$dest/cmdline-DRAFT.txt"
dtc -q -I dtb -O dts -o "$dest/board-PD-ONLY-NOT-BOOT-READY.dts" "$d"
diff -u /mnt/d/TB371FC-builds/r234-fsa-bus/board.dts "$dest/board-PD-ONLY-NOT-BOOT-READY.dts" > "$dest/DT.diff" || test "$?" = 1
cp /mnt/d/TB371FC-builds/r235-watchdog-only/r235-watchdog-only.ko "$dest/"
cp /mnt/d/TB371FC-builds/r236-current-limit/r233_pmic_tcpm.ko "$dest/"
cp /mnt/d/TB371FC-builds/r236-current-limit/tcpm.ko "$dest/"
cd "$dest"
sha256sum *.ko *.dtb > SHA256SUMS
cat SHA256SUMS
