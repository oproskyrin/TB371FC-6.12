#!/bin/sh
# One explicit stage per invocation; no panel GPIO, DSI, or GUI activation.
set -eu
dir=/run/r134
log=/run/r135
mkdir -p "$log"
phase=${1:-}
case "$phase" in rpmh|dispcc|icc|mdss) ;; *) echo 'usage: sh r135-display-stage.sh rpmh|dispcc|icc|mdss' >&2; exit 2;; esac
[ "$(uname -r)" = 6.12.30-tb371fc-r134-panel+ ]
for node in dsi@ae94000 dsi@ae96000; do
    [ "$(tr -d '\000' < /proc/device-tree/soc@0/display-subsystem@ae00000/$node/status)" = disabled ]
done
snapshot() {
    cp /sys/kernel/debug/clk/clk_summary "$log/$phase-$1-clocks.txt"
    cp /sys/kernel/debug/clk/clk_orphan_summary "$log/$phase-$1-orphans.txt"
    dmesg > "$log/$phase-$1-dmesg.txt"
    cat /proc/sys/kernel/random/boot_id /proc/uptime > "$log/$phase-$1-identity.txt"
}
load() {
    name=$1
    sysname=$(printf '%s' "$name" | tr - _)
    [ -d "/sys/module/$sysname" ] || timeout 20 insmod "$dir/modules/$name.ko"
}
snapshot before
case "$phase" in
rpmh)
    load clk-rpmh
    test -L /sys/devices/platform/soc@0/18200000.rsc/18200000.rsc:clock-controller/driver
    awk '$1 == "bi_tcxo" && $5 == 19200000 { ok=1 } END { exit !ok }' /sys/kernel/debug/clk/clk_summary
    ;;
dispcc)
    test -d /sys/module/clk_rpmh
    load dispcc-sm8250
    awk '$1 == "disp_cc_pll0" && $5 > 0 { a=1 } $1 == "disp_cc_pll1" && $5 > 0 { b=1 } END { exit !(a && b) }' /sys/kernel/debug/clk/clk_summary
    ;;
icc)
    test -d /sys/module/clk_rpmh
    test -d /sys/module/dispcc_sm8250
    for name in interconnect_qcom icc-bcm-voter icc-rpmh qnoc-sm8250; do load "$name"; done
    ;;
mdss)
    test -d /sys/module/qnoc_sm8250
    if [ ! -L /sys/devices/platform/soc@0/ae00000.display-subsystem/driver ]; then
        timeout 20 sh -c 'printf ae00000.display-subsystem > /sys/bus/platform/drivers/msm-mdss/bind'
    fi
    ;;
esac
snapshot after
printf 'R135: stage %s complete; native panel remains disabled\n' "$phase" | tee -a "$log/steps.txt"
exit 0
