#!/bin/sh
set -eu
bb=/run/tb371fc-rescue/busybox
kexec=/run/tb371fc-rescue/kexec
[ "$(uname -r)" = 4.19.157-perf-v56.6+ ]
testdir=/run/tb371fc-control-r139
mkdir -p "$testdir"
"$bb" tar -xzf /run/tb371fc-r139.tar.gz -C "$testdir"
[ "$("$bb" sha256sum "$testdir/Image" | "$bb" awk '{print $1}')" = 41b514a1487c5f2c314b63f458d9e62bb072b2ef94be4791bc4e7bec8c4e8450 ]
[ "$("$bb" sha256sum "$testdir/board.dtb" | "$bb" awk '{print $1}')" = 1f862a11b08408aed3f56a2542562417475d5a6b6af7120466b91d352ecab5ef ]
[ "$("$bb" sha256sum "$testdir/initramfs.cpio.gz" | "$bb" awk '{print $1}')" = e581c5f918fa4929b641f38fab974e676bab948ab3b24ada9741601fd6c1eb20 ]
/run/tb371fc-rescue/load-linux-6.12-r38
cmdline=$(sed -n "s/^cmdline='\(.*\)'$/\1/p" /run/tb371fc-rescue/load-linux-6.12-r38)
[ -n "$cmdline" ]
case "$cmdline" in *initcall_blacklist*|*tb371fc_tlmm_stop*) exit 1;; esac
cmdline="$cmdline systemd.show_status=1"
"$kexec" -u
"$kexec" -c -l "$testdir/Image" --dtb="$testdir/board.dtb" --initrd="$testdir/initramfs.cpio.gz" --append="$cmdline"
[ "$(cat /sys/kernel/kexec_loaded)" = 1 ]
mkdir -p /var/log/tb371fc-r121
{
    printf 'R139: exact R138 kernel/power; manual panel pinctrl, probe step0 default\ncmdline=%s\n' "$cmdline"
    "$bb" sha256sum "$testdir/Image" "$testdir/board.dtb" "$testdir/initramfs.cpio.gz"
    cat /proc/sys/kernel/random/boot_id /proc/uptime
} | tee /var/log/tb371fc-r121/r139-panel-gates.txt
exec /run/tb371fc-rescue/execute-linux-6.12-r38
