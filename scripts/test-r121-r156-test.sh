#!/bin/sh
# R140 runner for the first-stage 4.19 console. RAM kexec only, no flash.
set -eu
bb=/run/tb371fc-rescue/busybox
kexec=/run/tb371fc-rescue/kexec
testdir=/run/tb371fc-control-r156
mkdir -p "$testdir"
"$bb" tar -xzf /run/tb371fc-r156t.tar.gz -C "$testdir"
[ "$("$bb" sha256sum "$testdir/Image" | "$bb" awk '{print $1}')" = 03b2f15272040962984d70f77356b9686429f0b7024d85ed8fa4150b6129ec61 ]
[ "$("$bb" sha256sum "$testdir/board.dtb" | "$bb" awk '{print $1}')" = 5c05eea53b70888e5b0bbe70faa47d45d432ca5d5e85eb3e6d4f783d33abe21a ]
[ "$("$bb" sha256sum "$testdir/initramfs.cpio.gz" | "$bb" awk '{print $1}')" = 191523a19c7e30c358c79503a520bf1bcebd485e607210287ef61846a3bca055 ]
/run/tb371fc-rescue/load-linux-6.12-r38
cmdline=$(sed -n "s/^cmdline='\(.*\)'$/\1/p" /run/tb371fc-rescue/load-linux-6.12-r38)
[ -n "$cmdline" ]
case "$cmdline" in *initcall_blacklist*|*tb371fc_tlmm_stop*) exit 1;; esac
# nr_cpus can only lower nr_cpu_ids, so the old limit must be removed, not overridden.
cmdline=$(printf '%s' "$cmdline" | sed 's/ maxcpus=1 nr_cpus=1//')
case "$cmdline" in *maxcpus=*|*nr_cpus=*) exit 1;; esac
cmdline="$cmdline systemd.show_status=1"
"$kexec" -u
"$kexec" -c -l "$testdir/Image" --dtb="$testdir/board.dtb" --initrd="$testdir/initramfs.cpio.gz" --append="$cmdline"
[ "$(cat /sys/kernel/kexec_loaded)" = 1 ]
mkdir -p /var/log/tb371fc-r121
{
    printf 'R156t: R155 + rpmh SD rails DT, all CPUs\ncmdline=%s\n' "$cmdline"
    "$bb" sha256sum "$testdir/Image" "$testdir/board.dtb" "$testdir/initramfs.cpio.gz"
    cat /proc/sys/kernel/random/boot_id /proc/uptime
} | tee /var/log/tb371fc-r121/r156t.txt
/run/tb371fc-rescue/execute-linux-6.12-r38
