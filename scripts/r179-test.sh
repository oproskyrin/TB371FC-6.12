#!/bin/sh
# R179 test (first-stage 4.19 console): RAM kexec of the uploaded R179 payload (/run/tb371fc-r179.tar.gz). No flash.
set -u
bb=/run/tb371fc-rescue/busybox; kexec=/run/tb371fc-rescue/kexec; dir=/run/r179t
fail() { echo "R179 TEST: $*"; exit 1; }
mkdir -p $dir; "$bb" tar -xzf /run/tb371fc-r179.tar.gz -C $dir || fail extract
hash_ok() { [ "$("$bb" sha256sum "$dir/$1" 2>/dev/null | "$bb" awk '{print $1}')" = "$2" ]; }
hash_ok Image 3f6fb471992253a6d9c456353cd13517b8fccb0caaa0f2f4a12ab4d249f212ee || fail 'Image hash'
hash_ok board.dtb 9c82b4bf9be3230604874e6f71f445b4a8a6a821e45a42e49f99c0631e40b68b || fail 'DTB hash'
hash_ok initramfs.cpio.gz d0c2418e252e75bcbc46481988dce0199f55e2be4ed7ef3a1b48a88fb19b86b1 || fail 'initramfs hash'
cmdline='console=tty0 fbcon=font:TER16x32 earlycon=qcom_geni,0x988000 keep_bootcon ignore_loglevel loglevel=8 log_buf_len=8M rdinit=/init root=/dev/ram0 rw fw_devlink=off clk_ignore_unused pd_ignore_unused regulator_ignore_unused panic=0 initcall_debug printk.time=1 swiotlb=2048 reset_devices rodata=on systemd.unit=multi-user.target systemd.show_status=1 pci=realloc'
"$kexec" -u 2>/dev/null || true
"$kexec" -c -l "$dir/Image" --dtb="$dir/board.dtb" --initrd="$dir/initramfs.cpio.gz" --append="$cmdline" || fail 'kexec load failed'
[ "$(cat /sys/kernel/kexec_loaded)" = 1 ] || fail 'kexec_loaded is not 1'
echo loaded >/run/tb371fc-linux612-r38.state
echo 'R179 TEST: starting'
exec /run/tb371fc-rescue/execute-linux-6.12-r38
