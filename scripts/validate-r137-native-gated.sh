#!/usr/bin/env bash
set -euo pipefail
project="$(cd "$(dirname "$0")/.." && pwd)"
pkg=/mnt/d/TB371FC-builds/r137-native-prereqs
src=/root/tb371fc/linux-6.12-r137-native
stage=$(cat "$pkg/staging-path.txt")
(cd "$pkg"; sha256sum -c SHA256SUMS)
python3 "$project/scripts/verify-r137-native-prereqs.py" "$src"
python3 "$project/scripts/verify-r134-panel-source.py"
python3 "$project/scripts/verify-mainline-panel-order.py" "$src"
python3 "$project/scripts/verify-mainline-display-timing.py"
python3 "$project/scripts/verify-mainline-dsc-pps.py"
python3 "$project/scripts/audit-r137-display-power.py" "$pkg/board.dtb"
for file in "$pkg/modules/"*.ko; do modinfo -F vermagic "$file" | grep -q '^6.12.30-tb371fc-r137-native+ '; done
test "$(find "$pkg/modules" -name '*.ko' | wc -l)" -eq 11
grep -qx CONFIG_REGULATOR_QCOM_RPMH=m "$pkg/.config"
grep -qx CONFIG_QCOM_CLK_RPMH=m "$pkg/.config"
test "$(fdtget -t i "$pkg/board.dtb" /soc/pinctrl@f100000 gpio-reserved-ranges)" = '0 12 14 19 34 20 55 5 62 7 70 5 76 1 79 102'
for address in ae94400 ae96400; do
    test "$(fdtget -t s "$pkg/board.dtb" /soc/display-subsystem@ae00000/phy@$address compatible)" = lenovo,tb371fc-dsi-phy-7nm
done
for index in 0 1 2; do
    parent=/soc/rsc@18200000/regulators-$index
    for child in $(fdtget -l "$pkg/board.dtb" "$parent"); do
        case "$index/$child" in 0/ldo5|0/ldo9|0/ldo14) ;;
            *) test "$(fdtget -t s "$pkg/board.dtb" "$parent/$child" status)" = disabled;;
        esac
    done
done
(cd "$stage/r134-modules"; sha256sum -c "$stage/r134-config/r137-modules.sha256")
cmp "$stage/r130-modules/dwc3-qcom.ko" "$pkg/modules/dwc3-qcom.ko"
cmp "$stage/r130-modules/phy-qcom-snps-femto-v2.ko" "$pkg/modules/phy-qcom-snps-femto-v2.ko"
cmp "$stage/bin/boot-arch-r129-base" "$project/scripts/r129-overlay-arch-loader.sh"
cmp "$stage/r134-config/r137-native-stage.sh" "$project/scripts/r137-native-stage.sh"
cmp "$stage/r134-config/late-display-deps.sh" "$project/scripts/r137-clock-only.sh"
cmp "$stage/bin/boot-arch-development-rootfs" "$project/scripts/r137-boot-wrapper.sh"
sh -n "$stage/r134-config/r137-native-stage.sh"
sh -n "$project/scripts/test-r121-r137-native-gated.sh"
test ! -e "$stage/r130-config/id_ed25519"
printf 'PASS: R137 native-gated package OFFLINE; no physical display success claimed\n'
