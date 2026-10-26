#!/bin/sh
# Explicit native display gates. Does not launch KDE or change storage policy.
set -eu
dir=/run/r134
logs=/run/r137
mkdir -p "$logs"
phase=${1:-}
case "$phase" in rpmh|power|dispcc|icc|backlight|panel) ;; *) echo 'usage: stage rpmh|power|dispcc|icc|backlight|panel' >&2; exit 2;; esac
[ "$(uname -r)" = 6.12.30-tb371fc-r137-native+ ]
[ "$(tr -d '\000' < /proc/device-tree/soc@0/display-subsystem@ae00000/dsi@ae94000/panel@0/compatible)" = lenovo,tb371fc-tianma-nt36532novatek,nt36523 ]
(cd "$dir/modules"; sha256sum -c "$dir/config/r137-modules.sha256")
snapshot() {
    cat /proc/sys/kernel/random/boot_id /proc/uptime > "$logs/$phase-$1-identity.txt"
    dmesg > "$logs/$phase-$1-dmesg.txt"
    cat /sys/kernel/debug/clk/clk_summary > "$logs/$phase-$1-clocks.txt"
    cat /sys/kernel/debug/regulator/regulator_summary > "$logs/$phase-$1-regulators.txt"
    cat /sys/kernel/debug/devices_deferred > "$logs/$phase-$1-deferred.txt"
}
finish() {
    code=$?
    trap - EXIT
    snapshot after || true
    printf 'R137: phase=%s rc=%s; no GUI started\n' "$phase" "$code" | tee -a "$logs/steps.txt"
    exit "$code"
}
load() {
    sysname=$(printf '%s' "$1" | tr - _)
    [ -d "/sys/module/$sysname" ] || timeout 30 insmod "$dir/modules/$1.ko"
}
require() { test -f "$logs/$1.ok"; }
snapshot before
trap finish EXIT
case "$phase" in
rpmh)
    load clk-rpmh
    awk '$1 == "bi_tcxo" && $5 == 19200000 { ok=1 } END { exit !ok }' /sys/kernel/debug/clk/clk_summary
    ;;
power)
    require rpmh
    load qcom-rpmh-regulator
    for name in vreg_l5a_0p88 vreg_l9a_1p2 vreg_l14a_1p8; do
        grep -q "$name" /sys/kernel/debug/regulator/regulator_summary
    done
    ;;
dispcc)
    require power
    load dispcc-sm8250
    awk '$1 == "disp_cc_pll0" && $5 > 0 { a=1 } $1 == "disp_cc_pll1" && $5 > 0 { b=1 } END { exit !(a && b) }' /sys/kernel/debug/clk/clk_summary
    ;;
icc)
    require dispcc
    for name in interconnect_qcom icc-bcm-voter icc-rpmh qnoc-sm8250; do load "$name"; done
    if [ ! -e /sys/devices/platform/soc@0/ae00000.display-subsystem/driver ]; then
        timeout 20 sh -c 'printf ae00000.display-subsystem > /sys/bus/platform/drivers/msm-mdss/bind'
    fi
    ;;
backlight)
    require icc
    load tb371fc-ktz8866
    test -d /sys/class/backlight/tb371fc-panel-backlight
    ;;
panel)
    require backlight
    load panel-novatek-nt36523
    ls -l /sys/class/drm > "$logs/drm-after-panel.txt"
    # Registration alone is not acceptance: inspect connectors/modes and user photo.
    ;;
esac
touch "$logs/$phase.ok"
exit 0
