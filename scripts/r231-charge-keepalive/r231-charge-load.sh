#!/bin/sh
set -eu
grep -qw tb371fc.r226 /proc/cmdline
test "$(uname -r)" = 6.12.114-tb371fc-r199+
module=/usr/local/lib/tb371fc/$(uname -r)/r231-charge-keepalive.ko
test "$(sha256sum "$module" | cut -d ' ' -f1)" = 66bf214f03a6f5c47e6c36d51f5d770dbbd4de0ba613bd52a027d4d856610ba7
if [ -d /sys/module/r231_charge_keepalive ]; then
 test "$(cat /sys/module/r231_charge_keepalive/parameters/active)" = Y
 test "$(cat /sys/module/r231_charge_keepalive/parameters/fault)" = 0
 exit 0
fi
exec insmod "$module"
