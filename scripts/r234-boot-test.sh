#!/bin/sh
# Run ONLY in held 4.19 first-stage console, not current Arch userspace.
set -eu
case "$(uname -r)" in 4.19.157*) ;; *) echo 'Wrong boot stage'; exit 1;; esac
bb=/run/tb371fc-rescue/busybox
dir=/run/r234-test
mkdir -p "$dir"
"$bb" tar -xzf /run/r234-fsa-bus-payload.tar.gz -C "$dir"
check() { test "$("$bb" sha256sum "$dir/$1" | "$bb" awk '{print $1}')" = "$2"; }
check Image 7a59c7b2931c8e8925446a3cec5432a0912d5f0e3f9365058de2492ad6d0d157
check board.dtb 522b754fc5e04d89b0b8bdc78d7881ea3fa03d992dbfdee65f5c90531d6c7023
check initramfs.cpio.gz 0bcad91fa94af6ee794b85c52da12180709c729690a992864090981dc75f1219
cmdline='console=tty0 fbcon=font:TER16x32 earlycon=qcom_geni,0x988000 keep_bootcon ignore_loglevel loglevel=8 log_buf_len=8M rdinit=/init root=/dev/ram0 rw fw_devlink=off clk_ignore_unused pd_ignore_unused regulator_ignore_unused panic=0 initcall_debug printk.time=1 swiotlb=2048 reset_devices rodata=on systemd.unit=multi-user.target systemd.show_status=1 pci=realloc tb371fc.sd150 tb371fc.r226 tb371fc.usb3test tb371fc.r234'
/run/tb371fc-rescue/kexec -u 2>/dev/null || true
/run/tb371fc-rescue/kexec -c -l "$dir/Image" --dtb="$dir/board.dtb" --initrd="$dir/initramfs.cpio.gz" --append="$cmdline"
test "$(cat /sys/kernel/kexec_loaded)" = 1
echo loaded > /run/tb371fc-linux612-r38.state
echo 'R234 RAM test: QUP19 pins0/1 enabled; FSA driver disabled; no TCPC/DP changes'
exec /run/tb371fc-rescue/execute-linux-6.12-r38
