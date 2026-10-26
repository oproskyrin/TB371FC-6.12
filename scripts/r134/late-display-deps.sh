#!/bin/sh
set -eu
dir=/run/r134
mark() { printf 'R134: %s\n' "$*" | tee -a "$dir/steps.txt"; }
finish() {
    result=$?
    trap - EXIT
    set +e
    dmesg > "$dir/dmesg.txt"
    cat /sys/kernel/debug/devices_deferred > "$dir/deferred.txt"
    cat /sys/kernel/debug/pm_genpd/pm_genpd_summary > "$dir/domains.txt"
    cat /sys/kernel/debug/interconnect/interconnect_summary > "$dir/interconnect.txt"
    mark "display dependency control rc=$result; panel/backlight modules NOT loaded"
    exit "$result"
}
trap finish EXIT
for node in dsi@ae94000 dsi@ae96000; do
    status=/sys/devices/platform/soc@0/ae00000.display-subsystem/of_node/$node/status
    [ "$(tr -d '\000' < "$status")" = disabled ]
done
for name in dispcc-sm8250 interconnect_qcom icc-bcm-voter icc-rpmh qnoc-sm8250; do
    mark "loading $name after SSH"
    timeout 20 insmod "$dir/modules/$name.ko"
done
if [ ! -e /sys/devices/platform/soc@0/ae00000.display-subsystem/driver ]; then
    mark 'retrying MDSS bind'
    timeout 20 sh -c 'printf ae00000.display-subsystem > /sys/bus/platform/drivers/msm-mdss/bind'
fi
mark 'dependency control complete; waiting for separate native-panel test'
