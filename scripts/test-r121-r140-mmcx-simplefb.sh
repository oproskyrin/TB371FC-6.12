#!/bin/sh
# R140 runner for the first-stage 4.19 console. RAM kexec only, no flash.
set -eu
bb=/run/tb371fc-rescue/busybox
kexec=/run/tb371fc-rescue/kexec
testdir=/run/tb371fc-control-r140
mkdir -p "$testdir"
"$bb" tar -xzf /run/tb371fc-r140.tar.gz -C "$testdir"
[ "$("$bb" sha256sum "$testdir/Image" | "$bb" awk '{print $1}')" = 03b2f15272040962984d70f77356b9686429f0b7024d85ed8fa4150b6129ec61 ]
[ "$("$bb" sha256sum "$testdir/board.dtb" | "$bb" awk '{print $1}')" = 8890bca3d2743b0e9348e81cd0b1e77f2efa3307dd05a1d75e0106790aa2b314 ]
[ "$("$bb" sha256sum "$testdir/initramfs.cpio.gz" | "$bb" awk '{print $1}')" = cb68f76732b8c21c6ca8dfec7ca886c006082210fde78ede4da552d2fbcbaa70 ]
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
    printf 'R140: exact R131 kernel/initramfs/DT + simplefb power-domains=MMCX required-opps=NOM\ncmdline=%s\n' "$cmdline"
    "$bb" sha256sum "$testdir/Image" "$testdir/board.dtb" "$testdir/initramfs.cpio.gz"
    cat /proc/sys/kernel/random/boot_id /proc/uptime
} | tee /var/log/tb371fc-r121/r140-control.txt
/run/tb371fc-rescue/execute-linux-6.12-r38
