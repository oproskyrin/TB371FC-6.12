#!/bin/sh
# R184 test (first-stage 4.19 console): boot the staged R178 payload (/run/tb371fc-autoboot, copied
# from microSD by the console) with an uploaded test DTB (/run/r184-board.dtb). RAM kexec, no flash.
set -u
bb=/run/tb371fc-rescue/busybox; kexec=/run/tb371fc-rescue/kexec; dir=/run/tb371fc-autoboot
fail() { echo "R184 TEST: $*"; exit 1; }
hash_ok() { [ "$("$bb" sha256sum "$1" 2>/dev/null | "$bb" awk '{print $1}')" = "$2" ]; }
hash_ok $dir/Image 55fcf49e30a4abbe564cc17e255e107947346c7895016e2eb200011fdd117c0d || fail 'Image hash'
hash_ok $dir/initramfs.cpio.gz 291258e8d4dd2e16b343988a7df9565555c03dd9e12ff1ce198d641a83d4db3a || fail 'initramfs hash'
[ -f /run/r184-board.dtb ] || fail 'no test DTB'
"$bb" sha256sum /run/r184-board.dtb
cmdline='console=tty0 fbcon=font:TER16x32 earlycon=qcom_geni,0x988000 keep_bootcon ignore_loglevel loglevel=8 log_buf_len=8M rdinit=/init root=/dev/ram0 rw fw_devlink=off clk_ignore_unused pd_ignore_unused regulator_ignore_unused panic=0 initcall_debug printk.time=1 swiotlb=2048 reset_devices rodata=on systemd.unit=multi-user.target systemd.show_status=1 pci=realloc'
"$kexec" -u 2>/dev/null || true
"$kexec" -c -l "$dir/Image" --dtb=/run/r184-board.dtb --initrd="$dir/initramfs.cpio.gz" --append="$cmdline" || fail 'kexec load failed'
[ "$(cat /sys/kernel/kexec_loaded)" = 1 ] || fail 'kexec_loaded is not 1'
echo loaded >/run/tb371fc-linux612-r38.state
echo 'R184 TEST: starting R178 with the R184 battery DTB'
exec /run/tb371fc-rescue/execute-linux-6.12-r38
