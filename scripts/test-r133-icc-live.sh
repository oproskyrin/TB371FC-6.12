#!/bin/sh
set -eu
dir=/run/r133
mkdir -p "$dir"
tar -xzf /run/r133-icc-modules.tar.gz -C "$dir"
(cd "$dir"; sha256sum -c SHA256SUMS)
mark() { printf 'R133: %s\n' "$*" | tee -a "$dir/steps.txt"; }
finish() {
    result=$?
    trap - EXIT
    set +e
    dmesg > "$dir/dmesg.txt"
    cat /proc/modules > "$dir/modules.txt"
    cat /sys/kernel/debug/devices_deferred > "$dir/deferred.txt"
    cat /sys/kernel/debug/interconnect/interconnect_summary > "$dir/interconnect.txt"
    cat /proc/sys/kernel/random/boot_id > "$dir/boot-id.txt"
    mark "module sequence finished rc=$result"
    exit "$result"
}
trap finish EXIT
for name in interconnect_qcom icc-bcm-voter icc-rpmh; do
    mark "loading $name"
    timeout 15 insmod "$dir/$name.ko"
done
mark 'loading SM8250 NoC providers (hardware registration)'
timeout 45 insmod "$dir/qnoc-sm8250.ko"
mark 'NoC registration returned'
ls -l /sys/bus/platform/drivers/qnoc-sm8250
cat /sys/kernel/debug/devices_deferred
exit 0
