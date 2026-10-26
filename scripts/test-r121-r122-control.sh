#!/bin/sh
# Recompiled baseline control; Image hash supplied from audited host artifact.
set -eu
expected=${1:?Expected Image SHA256 required}
[ ${#expected} -eq 64 ]
image=/run/tb371fc-control-r122.Image
bb=/run/tb371fc-rescue/busybox
kexec=/run/tb371fc-rescue/kexec
payload=/run/tb371fc-rescue/linux-6.12-r38
[ "$("$bb" sha256sum "$image" | "$bb" awk '{print $1}')" = "$expected" ]
/run/tb371fc-rescue/load-linux-6.12-r38
cmdline=$(sed -n "s/^cmdline='\(.*\)'$/\1/p" /run/tb371fc-rescue/load-linux-6.12-r38)
[ -n "$cmdline" ]
"$kexec" -u
"$kexec" -c -l "$image" --dtb="$payload/board.dtb" --initrd="$payload/initramfs.cpio.gz" --append="$cmdline"
[ "$(cat /sys/kernel/kexec_loaded)" = 1 ]
mkdir -p /var/log/tb371fc-r121
printf 'r122 rebuilt baseline Image: %s\ncmdline=%s\n' "$expected" "$cmdline" | tee /var/log/tb371fc-r121/r122-control.txt
cat /proc/sys/kernel/random/boot_id /proc/uptime
/run/tb371fc-rescue/execute-linux-6.12-r38
