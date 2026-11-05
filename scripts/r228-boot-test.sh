#!/bin/sh
set -eu
bb=/run/tb371fc-rescue/busybox
dir=/run/r228-test
mkdir -p "$dir"
"$bb" tar -xzf /run/r228-otg-payload.tar.gz -C "$dir"
check() { test "$("$bb" sha256sum "$dir/$1" | "$bb" awk '{print $1}')" = "$2"; }
check Image 7a59c7b2931c8e8925446a3cec5432a0912d5f0e3f9365058de2492ad6d0d157
check board.dtb c7a7139791800c293bceb73b460d8732ce7126b4c351185754ea91546c4a0dc5
check initramfs.cpio.gz 0bcad91fa94af6ee794b85c52da12180709c729690a992864090981dc75f1219
cmdline='console=tty0 fbcon=font:TER16x32 earlycon=qcom_geni,0x988000 keep_bootcon ignore_loglevel loglevel=8 log_buf_len=8M rdinit=/init root=/dev/ram0 rw fw_devlink=off clk_ignore_unused pd_ignore_unused regulator_ignore_unused panic=0 initcall_debug printk.time=1 swiotlb=2048 reset_devices rodata=on systemd.unit=multi-user.target systemd.show_status=1 pci=realloc tb371fc.sd150 tb371fc.r226 tb371fc.usb3test tb371fc.r228'
/run/tb371fc-rescue/kexec -u 2>/dev/null || true
/run/tb371fc-rescue/kexec -c -l "$dir/Image" --dtb="$dir/board.dtb" --initrd="$dir/initramfs.cpio.gz" --append="$cmdline"
test "$(cat /sys/kernel/kexec_loaded)" = 1
echo loaded > /run/tb371fc-linux612-r38.state
echo 'R228 temporary initialized OTG; default DEVICE, no TCPM or VBUS enable'
exec /run/tb371fc-rescue/execute-linux-6.12-r38
