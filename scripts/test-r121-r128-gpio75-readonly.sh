#!/bin/sh
set -eu
bb=/run/tb371fc-rescue/busybox
kexec=/run/tb371fc-rescue/kexec
payload=/run/tb371fc-rescue/linux-6.12-r38
testdir=/run/tb371fc-control-r128
mkdir -p "$testdir"
"$bb" tar -xzf /run/tb371fc-r128.tar.gz -C "$testdir"
[ "$("$bb" sha256sum "$payload/Image" | "$bb" awk '{print $1}')" = dbcffeead9750aa41228269f2101c32c76cbde42d1bea554db1132ad30eac11d ]
[ "$("$bb" sha256sum "$testdir/board.dtb" | "$bb" awk '{print $1}')" = 0e312dab299e034b056e1e2e6550c7726415bf6a161cf074bc1f077c6432f828 ]
[ "$("$bb" sha256sum "$testdir/initramfs.cpio.gz" | "$bb" awk '{print $1}')" = 7812d7f6c84376b44f50c6eaf6a4b1f3afbe1a37e87ff42db4b0fe10a5216050 ]
/run/tb371fc-rescue/load-linux-6.12-r38
cmdline=$(sed -n "s/^cmdline='\(.*\)'$/\1/p" /run/tb371fc-rescue/load-linux-6.12-r38)
[ -n "$cmdline" ]
case "$cmdline" in *initcall_blacklist*|*tb371fc_tlmm_stop*) exit 1;; esac
"$kexec" -u
"$kexec" -c -l "$payload/Image" --dtb="$testdir/board.dtb" --initrd="$testdir/initramfs.cpio.gz" --append="$cmdline"
[ "$(cat /sys/kernel/kexec_loaded)" = 1 ]
mkdir -p /var/log/tb371fc-r121
{
    printf 'R128: GPIO75 only; redriver hog enabled; read-only SD probe\ncmdline=%s\n' "$cmdline"
    "$bb" sha256sum "$payload/Image" "$testdir/board.dtb" "$testdir/initramfs.cpio.gz"
    cat /proc/sys/kernel/random/boot_id /proc/uptime
} | tee /var/log/tb371fc-r121/r128-control.txt
/run/tb371fc-rescue/execute-linux-6.12-r38
