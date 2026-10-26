#!/bin/sh
# R140 runner for the first-stage 4.19 console. RAM kexec only, no flash.
set -eu
bb=/run/tb371fc-rescue/busybox
kexec=/run/tb371fc-rescue/kexec
testdir=/run/tb371fc-control-r163
mkdir -p "$testdir"
"$bb" tar -xzf /run/tb371fc-r163.tar.gz -C "$testdir"
[ "$("$bb" sha256sum "$testdir/Image" | "$bb" awk '{print $1}')" = 62763187b5dc1958419462a83bbd2f0cc9fa19f31bf0e3700cd1167314172dac ]
[ "$("$bb" sha256sum "$testdir/board.dtb" | "$bb" awk '{print $1}')" = 3ddc9d5856c9cd559752a3753190922fef0bafe3fc27694f57b0e16cf710c221 ]
[ "$("$bb" sha256sum "$testdir/initramfs.cpio.gz" | "$bb" awk '{print $1}')" = 56264a181e9d0e733bcb8017e2ad206131be909397e2bd0d70935065c2e33d98 ]
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
    printf 'R163: R159 audio kernel + R161 DTB + R163 autostart initramfs + R158 initramfs (rebuilt modules), all CPUs\ncmdline=%s\n' "$cmdline"
    "$bb" sha256sum "$testdir/Image" "$testdir/board.dtb" "$testdir/initramfs.cpio.gz"
    cat /proc/sys/kernel/random/boot_id /proc/uptime
} | tee /var/log/tb371fc-r121/r163.txt
/run/tb371fc-rescue/execute-linux-6.12-r38
