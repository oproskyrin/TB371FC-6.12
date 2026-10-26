#!/bin/sh
# R123 experiment: exact R118 payload, only skip SM8250 pinctrl registration.
# Not an SD fix or a new kernel build. Execute through the first-stage SSH gate.
set -eu
bb=/run/tb371fc-rescue/busybox
kexec=/run/tb371fc-rescue/kexec
payload=/run/tb371fc-rescue/linux-6.12-r38
image=$payload/Image
expected=dbcffeead9750aa41228269f2101c32c76cbde42d1bea554db1132ad30eac11d
[ "$("$bb" sha256sum "$image" | "$bb" awk '{print $1}')" = "$expected" ]
/run/tb371fc-rescue/load-linux-6.12-r38
cmdline=$(sed -n "s/^cmdline='\(.*\)'$/\1/p" /run/tb371fc-rescue/load-linux-6.12-r38)
[ -n "$cmdline" ]
case "$cmdline" in *initcall_blacklist*) echo 'Unexpected existing blacklist'; exit 1;; esac
cmdline="$cmdline initcall_blacklist=sm8250_pinctrl_init"
"$kexec" -u
"$kexec" -c -l "$image" --dtb="$payload/board.dtb" --initrd="$payload/initramfs.cpio.gz" --append="$cmdline"
[ "$(cat /sys/kernel/kexec_loaded)" = 1 ]
mkdir -p /var/log/tb371fc-r121
{
    printf 'R123: exact R118 Image; skip sm8250_pinctrl_init\ncmdline=%s\n' "$cmdline"
    "$bb" sha256sum "$image" "$payload/board.dtb" "$payload/initramfs.cpio.gz"
    cat /proc/sys/kernel/random/boot_id /proc/uptime
} | tee /var/log/tb371fc-r121/r123-control.txt
/run/tb371fc-rescue/execute-linux-6.12-r38
