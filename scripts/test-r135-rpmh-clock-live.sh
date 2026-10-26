#!/bin/sh
set -eu
[ "$(uname -r)" = 6.12.30-tb371fc-r134-panel+ ]
[ "$(cat /proc/sys/kernel/random/boot_id)" = ae48fe3d-6286-4e32-824c-18ce271c0bdf ]
dir=/run/r135
mkdir -p "$dir"
[ "$(sha256sum "$dir/clk-rpmh.ko" | awk '{print $1}')" = 5a281e712dbea7b96f92c269e36f0c49df96882a9515b48b98aac4a5931ffeeb ]
test ! -d /sys/module/clk_rpmh
cp /sys/kernel/debug/clk/clk_summary "$dir/clocks-before.txt"
cp /sys/kernel/debug/clk/clk_orphan_summary "$dir/orphans-before.txt"
cat /proc/sys/kernel/random/boot_id /proc/uptime > "$dir/identity-before.txt"
timeout 20 insmod "$dir/clk-rpmh.ko"
cp /sys/kernel/debug/clk/clk_summary "$dir/clocks-after.txt"
cp /sys/kernel/debug/clk/clk_orphan_summary "$dir/orphans-after.txt"
dmesg > "$dir/dmesg.txt"
readlink /sys/devices/platform/soc@0/18200000.rsc/18200000.rsc:clock-controller/driver
grep -E '(^| )((bi_tcxo|disp_cc_pll)[a-zA-Z0-9_]*) ' "$dir/clocks-after.txt"
systemctl is-active r130-sshd.service
cat /proc/sys/kernel/random/boot_id /proc/uptime
exit 0
