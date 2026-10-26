#!/bin/sh
# R174 (first-stage 4.19 console): kexec the RAM-only maintenance payload (uploaded to
# /run/tb371fc-r174-maint.tar.gz). Linux 6.12 then stops before mounting the microSD.
set -u
bb=/run/tb371fc-rescue/busybox; kexec=/run/tb371fc-rescue/kexec; dir=/run/r174-maint
fail() { echo "BOOT-MAINT: $*"; exit 1; }
mkdir -p $dir; "$bb" tar -xzf /run/tb371fc-r174-maint.tar.gz -C $dir || fail 'extract'
hash_ok() { [ "$("$bb" sha256sum "$dir/$1" 2>/dev/null | "$bb" awk '{print $1}')" = "$2" ]; }
hash_ok Image 62763187b5dc1958419462a83bbd2f0cc9fa19f31bf0e3700cd1167314172dac || fail 'Image hash mismatch'
hash_ok board.dtb d341922a8ee8393b95637933751f1ea5584bb9659bed3ea32ebcb85818876ca2 || fail 'DTB hash mismatch'
hash_ok initramfs.cpio.gz a176c98d136a6665f8e72e2be289520bb92ccf3d8fcc31a4c0b053f2750a8bfb || fail 'initramfs hash mismatch'
[ -x "$kexec" ] && [ -x /run/tb371fc-rescue/execute-linux-6.12-r38 ] || fail 'kexec helpers missing'
cmdline='console=tty0 fbcon=font:TER16x32 earlycon=qcom_geni,0x988000 keep_bootcon ignore_loglevel loglevel=8 log_buf_len=8M rdinit=/init root=/dev/ram0 rw fw_devlink=off clk_ignore_unused pd_ignore_unused regulator_ignore_unused panic=0 printk.time=1 swiotlb=2048 reset_devices rodata=on tb371fc.maint'
sync
"$kexec" -u 2>/dev/null || true
"$kexec" -c -l "$dir/Image" --dtb="$dir/board.dtb" --initrd="$dir/initramfs.cpio.gz" --append="$cmdline" || fail 'kexec load failed'
[ "$(cat /sys/kernel/kexec_loaded)" = 1 ] || fail 'kexec_loaded is not 1'
echo loaded >/run/tb371fc-linux612-r38.state
echo 'TB371FC: starting Linux 6.12 MAINTENANCE (RAM only) now.'
exec /run/tb371fc-rescue/execute-linux-6.12-r38
