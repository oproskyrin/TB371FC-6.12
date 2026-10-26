#!/bin/sh
# R181 test (first-stage 4.19 console): RAM kexec of the uploaded R181 payload (/run/tb371fc-r181.tar.gz). No flash.
set -u
bb=/run/tb371fc-rescue/busybox; kexec=/run/tb371fc-rescue/kexec; dir=/run/r181t
fail() { echo "R181 TEST: $*"; exit 1; }
mkdir -p $dir; "$bb" tar -xzf /run/tb371fc-r181.tar.gz -C $dir || fail extract
hash_ok() { [ "$("$bb" sha256sum "$dir/$1" 2>/dev/null | "$bb" awk '{print $1}')" = "$2" ]; }
hash_ok Image db676c25c50a9160fbad966b46ae96947fee986a916539e394a4dbb7fdfc024d || fail 'Image hash'
hash_ok board.dtb 39bdfe6fea799cf4823f1049e5f9f9e1da344f831afe594681d3be430ffd05ff || fail 'DTB hash'
hash_ok initramfs.cpio.gz 291258e8d4dd2e16b343988a7df9565555c03dd9e12ff1ce198d641a83d4db3a || fail 'initramfs hash'
cmdline='console=tty0 fbcon=font:TER16x32 earlycon=qcom_geni,0x988000 keep_bootcon ignore_loglevel loglevel=8 log_buf_len=8M rdinit=/init root=/dev/ram0 rw fw_devlink=off clk_ignore_unused pd_ignore_unused regulator_ignore_unused panic=0 initcall_debug printk.time=1 swiotlb=2048 reset_devices rodata=on systemd.unit=multi-user.target systemd.show_status=1 pci=realloc'
"$kexec" -u 2>/dev/null || true
"$kexec" -c -l "$dir/Image" --dtb="$dir/board.dtb" --initrd="$dir/initramfs.cpio.gz" --append="$cmdline" || fail 'kexec load failed'
[ "$(cat /sys/kernel/kexec_loaded)" = 1 ] || fail 'kexec_loaded is not 1'
echo loaded >/run/tb371fc-linux612-r38.state
echo 'R181 TEST: starting'
exec /run/tb371fc-rescue/execute-linux-6.12-r38
