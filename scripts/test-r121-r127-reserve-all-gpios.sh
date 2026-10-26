#!/bin/sh
set -eu
expected=${1:?DTB SHA256 required}
[ ${#expected} -eq 64 ]
bb=/run/tb371fc-rescue/busybox
kexec=/run/tb371fc-rescue/kexec
payload=/run/tb371fc-rescue/linux-6.12-r38
dtb=/run/tb371fc-control-r127.dtb
[ "$("$bb" sha256sum "$dtb" | "$bb" awk '{print $1}')" = "$expected" ]
[ "$("$bb" sha256sum "$payload/Image" | "$bb" awk '{print $1}')" = dbcffeead9750aa41228269f2101c32c76cbde42d1bea554db1132ad30eac11d ]
/run/tb371fc-rescue/load-linux-6.12-r38
cmdline=$(sed -n "s/^cmdline='\(.*\)'$/\1/p" /run/tb371fc-rescue/load-linux-6.12-r38)
[ -n "$cmdline" ]
case "$cmdline" in *initcall_blacklist*|*tb371fc_tlmm_stop*) exit 1;; esac
"$kexec" -u
"$kexec" -c -l "$payload/Image" --dtb="$dtb" --initrd="$payload/initramfs.cpio.gz" --append="$cmdline"
[ "$(cat /sys/kernel/kexec_loaded)" = 1 ]
mkdir -p /var/log/tb371fc-r121
{
    printf 'R127: exact R118 Image; R125 DTB with all 181 GPIOs reserved\ncmdline=%s\n' "$cmdline"
    "$bb" sha256sum "$payload/Image" "$dtb" "$payload/initramfs.cpio.gz"
    cat /proc/sys/kernel/random/boot_id /proc/uptime
} | tee /var/log/tb371fc-r121/r127-control.txt
/run/tb371fc-rescue/execute-linux-6.12-r38
