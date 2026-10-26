#!/bin/sh
set -eu
expected=${1:?Image SHA256 required}
stop=${2:-4}
case "$stop" in 0|1|2|3|4|5|6) ;; *) exit 1;; esac
bb=/run/tb371fc-rescue/busybox
kexec=/run/tb371fc-rescue/kexec
payload=/run/tb371fc-rescue/linux-6.12-r38
testdir=/run/tb371fc-control-r126
mkdir -p "$testdir"
"$bb" tar -xzf /run/tb371fc-r126.tar.gz -C "$testdir"
[ "$("$bb" sha256sum "$testdir/Image" | "$bb" awk '{print $1}')" = "$expected" ]
[ "$("$bb" sha256sum "$testdir/board.dtb" | "$bb" awk '{print $1}')" = 95c53bfe82d42c11110b2eb970167962a9ee0583e688071c594e1fa198719afe ]
/run/tb371fc-rescue/load-linux-6.12-r38
cmdline=$(sed -n "s/^cmdline='\(.*\)'$/\1/p" /run/tb371fc-rescue/load-linux-6.12-r38)
[ -n "$cmdline" ]
case "$cmdline" in *initcall_blacklist*|*tb371fc_tlmm_stop*) exit 1;; esac
cmdline="$cmdline tb371fc_tlmm_stop=$stop"
"$kexec" -u
"$kexec" -c -l "$testdir/Image" --dtb="$testdir/board.dtb" --initrd="$payload/initramfs.cpio.gz" --append="$cmdline"
[ "$(cat /sys/kernel/kexec_loaded)" = 1 ]
mkdir -p /var/log/tb371fc-r121
{
    printf 'R126 instrumented TLMM; stop=%s\ncmdline=%s\n' "$stop" "$cmdline"
    "$bb" sha256sum "$testdir/Image" "$testdir/board.dtb" "$payload/initramfs.cpio.gz"
    cat /proc/sys/kernel/random/boot_id /proc/uptime
} | tee "/var/log/tb371fc-r121/r126-stop-$stop-control.txt"
/run/tb371fc-rescue/execute-linux-6.12-r38
