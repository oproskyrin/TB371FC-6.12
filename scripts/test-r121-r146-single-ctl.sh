#!/bin/sh
set -eu
bb=/run/tb371fc-rescue/busybox
kexec=/run/tb371fc-rescue/kexec
[ "$(uname -r)" = 4.19.157-perf-v56.6+ ]
testdir=/run/tb371fc-control-r146
mkdir -p "$testdir"
"$bb" tar -xzf /run/tb371fc-r146.tar.gz -C "$testdir"
[ "$("$bb" sha256sum "$testdir/Image" | "$bb" awk '{print $1}')" = 00b78e9d49c0ba22fbc3fb14095a29d47299671b25aab276b73a7e4646a12255 ]
[ "$("$bb" sha256sum "$testdir/board.dtb" | "$bb" awk '{print $1}')" = 2d11e9fe78efcdf5615aa05d73d10bebf3bb8785a8ecc4e38dd8b51d09b95b74 ]
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
    printf 'R146: R144 + 7.1 single-CTL model\ncmdline=%s\n' "$cmdline"
    "$bb" sha256sum "$testdir/Image" "$testdir/board.dtb" "$testdir/initramfs.cpio.gz"
    cat /proc/sys/kernel/random/boot_id /proc/uptime
} | tee /var/log/tb371fc-r121/r146-single-ctl.txt
exec /run/tb371fc-rescue/execute-linux-6.12-r38
