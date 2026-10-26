#!/bin/sh
# R182 test (first-stage 4.19 console): RAM kexec of the uploaded R182 payload (/run/tb371fc-r182s.tar.gz). No flash.
set -u
bb=/run/tb371fc-rescue/busybox; kexec=/run/tb371fc-rescue/kexec; dir=/run/r182st
fail() { echo "R182 TEST: $*"; exit 1; }
mkdir -p $dir; "$bb" tar -xzf /run/tb371fc-r182s.tar.gz -C $dir || fail extract
hash_ok() { [ "$("$bb" sha256sum "$dir/$1" 2>/dev/null | "$bb" awk '{print $1}')" = "$2" ]; }
hash_ok Image 0088205656a046402639dd1b71d92e4fb83440b01e74f7f3e4f80df1b60c8dd1 || fail 'Image hash'
hash_ok board.dtb 4c806eee120767664bb69452e812b8f762c97c045dfd5a210230e967c9e80238 || fail 'DTB hash'
hash_ok initramfs.cpio.gz 291258e8d4dd2e16b343988a7df9565555c03dd9e12ff1ce198d641a83d4db3a || fail 'initramfs hash'
cmdline='console=tty0 fbcon=font:TER16x32 earlycon=qcom_geni,0x988000 keep_bootcon ignore_loglevel loglevel=8 log_buf_len=8M rdinit=/init root=/dev/ram0 rw fw_devlink=off clk_ignore_unused pd_ignore_unused regulator_ignore_unused panic=0 initcall_debug printk.time=1 swiotlb=2048 reset_devices rodata=on systemd.unit=multi-user.target systemd.show_status=1 pci=realloc'
"$kexec" -u 2>/dev/null || true
"$kexec" -c -l "$dir/Image" --dtb="$dir/board.dtb" --initrd="$dir/initramfs.cpio.gz" --append="$cmdline" || fail 'kexec load failed'
[ "$(cat /sys/kernel/kexec_loaded)" = 1 ] || fail 'kexec_loaded is not 1'
echo loaded >/run/tb371fc-linux612-r38.state
echo 'R182 TEST: starting'
exec /run/tb371fc-rescue/execute-linux-6.12-r38
