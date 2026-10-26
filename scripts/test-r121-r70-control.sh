#!/bin/sh
# Single-variable hardware control: r70 Image, unchanged r121 DT/initramfs.
set -eu
image=/run/tb371fc-control-r70.Image
bb=/run/tb371fc-rescue/busybox
kexec=/run/tb371fc-rescue/kexec
payload=/run/tb371fc-rescue/linux-6.12-r38
expected=9644d29f837f0d52f7b25dcc19a4ea6b495833782810f2e6a933d74dacfd662f
[ "$("$bb" sha256sum "$image" | "$bb" awk '{print $1}')" = "$expected" ]
# Existing loader verifies the unchanged Image/DT/initramfs and makes state.
/run/tb371fc-rescue/load-linux-6.12-r38
cmdline=$(sed -n "s/^cmdline='\(.*\)'$/\1/p" /run/tb371fc-rescue/load-linux-6.12-r38)
[ -n "$cmdline" ]
"$kexec" -u
"$kexec" -c -l "$image" --dtb="$payload/board.dtb" --initrd="$payload/initramfs.cpio.gz" --append="$cmdline"
[ "$(cat /sys/kernel/kexec_loaded)" = 1 ]
mkdir -p /var/log/tb371fc-r121
printf 'r70 Image control: %s\ncmdline=%s\n' "$expected" "$cmdline" | tee /var/log/tb371fc-r121/r70-control.txt
cat /proc/sys/kernel/random/boot_id /proc/uptime
/run/tb371fc-rescue/execute-linux-6.12-r38
