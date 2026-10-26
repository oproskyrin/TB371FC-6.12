#!/bin/sh
set -eu
bb=/run/tb371fc-rescue/busybox
kexec=/run/tb371fc-rescue/kexec
[ "$(uname -r)" = 4.19.157-perf-v56.6+ ]
testdir=/run/tb371fc-control-r137
mkdir -p "$testdir"
"$bb" tar -xzf /run/tb371fc-r137.tar.gz -C "$testdir"
[ "$("$bb" sha256sum "$testdir/Image" | "$bb" awk '{print $1}')" = 41b514a1487c5f2c314b63f458d9e62bb072b2ef94be4791bc4e7bec8c4e8450 ]
[ "$("$bb" sha256sum "$testdir/board.dtb" | "$bb" awk '{print $1}')" = e13d514b00ff8fa12ed975685b9b57d1eb605f2e0063d8de70a17ef4387f02a5 ]
[ "$("$bb" sha256sum "$testdir/initramfs.cpio.gz" | "$bb" awk '{print $1}')" = 8a74557366d0a8a47595bde7436c768e3fccc9f0e41e9068598bc52d216be853 ]
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
    printf 'R137: native DSI/PHY DT armed; only RPMh clock loaded automatically after SSH\ncmdline=%s\n' "$cmdline"
    "$bb" sha256sum "$testdir/Image" "$testdir/board.dtb" "$testdir/initramfs.cpio.gz"
    cat /proc/sys/kernel/random/boot_id /proc/uptime
} | tee /var/log/tb371fc-r121/r137-native-gated.txt
exec /run/tb371fc-rescue/execute-linux-6.12-r38
