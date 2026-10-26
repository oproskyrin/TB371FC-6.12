#!/usr/bin/env bash
set -euo pipefail
project="$(cd "$(dirname "$0")/.." && pwd)"
base=/mnt/d/TB371FC-builds/linux-6.12-r134-panel/board.dtb
pkg=/mnt/d/TB371FC-builds/r137-native-prereqs
dtb="$pkg/native-gated.dtb"
if [ -e "$dtb" ]; then test "${1:-}" = --rebuild; fi
printf '%s  %s\n' 7c11303edcd7a0b8b21389a5065f8048f36d81cefe358a6f5f9297edc76a9aab "$base" | sha256sum -c -
cp "$base" "$dtb"
mdss=/soc/display-subsystem@ae00000
tlmm=/soc/pinctrl@f100000
# Keep every other GPIO reserved, including unrelated I2C/keyboard/WLAN pins.
# Allowed: backlight I2C12/13,60/61; stock display33/54/69/77/78; existing SD75.
fdtput -t i "$dtb" "$tlmm" gpio-reserved-ranges 0 12 14 19 34 20 55 5 62 7 70 5 76 1 79 102
fdtput -p -c "$dtb" "$tlmm/r137-display-active"
fdtput -t x "$dtb" "$tlmm/r137-display-active" phandle 7002
fdtput -t s "$dtb" "$tlmm/r137-display-active" pins gpio33 gpio54 gpio77 gpio78
fdtput -t s "$dtb" "$tlmm/r137-display-active" function gpio
fdtput -t i "$dtb" "$tlmm/r137-display-active" drive-strength 2
fdtput "$dtb" "$tlmm/r137-display-active" bias-pull-down
fdtput "$dtb" "$tlmm/r137-display-active" output-high

for item in '994000 7000 primary' 'a8c000 7001 secondary'; do
    read -r address handle role <<< "$item"
    node="/soc/geniqup@$(test "$address" = 994000 && echo 9c0000 || echo ac0000)/i2c@$address"
    # Resolve actual parent from decoded tree if controller layout differs.
    test "$(fdtget -t s "$dtb" "$node" compatible)" = qcom,geni-i2c
    fdtput -t s "$dtb" "$node" status okay
    fdtput -t i "$dtb" "$node" clock-frequency 400000
    fdtput -p -c "$dtb" "$node/backlight@11"
    fdtput -t s "$dtb" "$node/backlight@11" compatible lenovo,tb371fc-ktz8866
    fdtput -t x "$dtb" "$node/backlight@11" reg 11
    fdtput -t x "$dtb" "$node/backlight@11" phandle "$handle"
    if [ "$role" = primary ]; then fdtput "$dtb" "$node/backlight@11" lenovo,primary-backlight; fi
done
fdtput -t s "$dtb" "$mdss/display-controller@ae01000" compatible lenovo,tb371fc-dpu
# Unused DP PHY is deliberately off in this port; do not include it in native bind.
fdtput -t s "$dtb" "$mdss/displayport-controller@ae90000" status disabled
for address in ae94400 ae96400; do
    fdtput -t s "$dtb" "$mdss/phy@$address" compatible lenovo,tb371fc-dsi-phy-7nm
    fdtput -t s "$dtb" "$mdss/phy@$address" status okay
done
for address in ae94000 ae96000; do fdtput -t s "$dtb" "$mdss/dsi@$address" status okay; done
panel="$mdss/dsi@ae94000/panel@0"
fdtput -t s "$dtb" "$panel" compatible lenovo,tb371fc-tianma-nt36532 novatek,nt36523
fdtput -t x "$dtb" "$panel" backlight 7000
fdtput -t x "$dtb" "$panel" pinctrl-0 7002
fdtput -t s "$dtb" "$panel" pinctrl-names default
fdtput -t s "$dtb" "$panel" status okay
# Register ONLY the three declared display LDOs during the power-stage test.
# Avoid initial constraints touching unrelated rails in this candidate.
for index in 0 1 2; do
    parent=/soc/rsc@18200000/regulators-$index
    for child in $(fdtget -l "$dtb" "$parent"); do
        case "$index/$child" in 0/ldo5|0/ldo9|0/ldo14) ;;
            *) fdtput -t s "$dtb" "$parent/$child" status disabled;;
        esac
    done
done
dtc -q -s -I dtb -O dts "$base" > "$pkg/baseline-r131.dts"
dtc -q -s -I dtb -O dts "$dtb" > "$pkg/native-gated.dts"
diff -u "$pkg/baseline-r131.dts" "$pkg/native-gated.dts" > "$pkg/native-dtb.diff" || test "$?" = 1
python3 "$project/scripts/audit-r137-display-power.py" "$dtb" > "$pkg/display-power-audit.txt"
sha256sum "$dtb"
