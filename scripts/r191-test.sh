#!/bin/sh
set -eu
bb=/run/tb371fc-rescue/busybox
dir=/run/r191t
mkdir -p "$dir"
"$bb" tar -xzf /run/tb371fc-r191.tar.gz -C "$dir"
check() { test "$("$bb" sha256sum "$dir/$1" | "$bb" awk '{print $1}')" = "$2"; }
check Image 9ba5044bec28639a6d94de223ae7e2282bf9e0e1339cb13e0dd6a4a88f4c642c
check board.dtb 52a5d5775c04f88d3e424b767ad6e0f7e04540aace7df024b732d96e75c84bc6
check initramfs.cpio.gz d0c2418e252e75bcbc46481988dce0199f55e2be4ed7ef3a1b48a88fb19b86b1
cmdline='console=tty0 fbcon=font:TER16x32 earlycon=qcom_geni,0x988000 keep_bootcon ignore_loglevel loglevel=8 log_buf_len=8M rdinit=/init root=/dev/ram0 rw fw_devlink=off clk_ignore_unused pd_ignore_unused regulator_ignore_unused panic=0 initcall_debug printk.time=1 swiotlb=2048 reset_devices rodata=on systemd.unit=multi-user.target systemd.show_status=1 pci=realloc'
/run/tb371fc-rescue/kexec -u 2>/dev/null || true
/run/tb371fc-rescue/kexec -c -l "$dir/Image" --dtb="$dir/board.dtb" --initrd="$dir/initramfs.cpio.gz" --append="$cmdline"
test "$(cat /sys/kernel/kexec_loaded)" = 1
echo loaded > /run/tb371fc-linux612-r38.state
exec /run/tb371fc-rescue/execute-linux-6.12-r38
