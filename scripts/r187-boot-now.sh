#!/bin/sh
# Boot the staged autoboot payload now (remote): same hash pins and kexec as the R187 helper, no countdown.
set -u
bb=/run/tb371fc-rescue/busybox; kexec=/run/tb371fc-rescue/kexec; dir=/run/tb371fc-autoboot
fail() { echo "BOOT-NOW: $*"; exit 1; }
hash_ok() { [ "$("$bb" sha256sum "$dir/$1" 2>/dev/null | "$bb" awk '{print $1}')" = "$2" ]; }
hash_ok Image 2d412d9b57a184a5c4a516e1e72133aff0717700efed5617f72631b953832f77 || fail 'Image hash mismatch'
hash_ok board.dtb a02916b971a9930c57da05485ef8e1ea63e0e669832286d11e17d8b0603cb79d || fail 'DTB hash mismatch'
hash_ok initramfs.cpio.gz d0c2418e252e75bcbc46481988dce0199f55e2be4ed7ef3a1b48a88fb19b86b1 || fail 'initramfs hash mismatch'
[ -x "$kexec" ] && [ -x /run/tb371fc-rescue/execute-linux-6.12-r38 ] || fail 'kexec helpers missing'
cmdline='console=tty0 fbcon=font:TER16x32 earlycon=qcom_geni,0x988000 keep_bootcon ignore_loglevel loglevel=8 log_buf_len=8M rdinit=/init root=/dev/ram0 rw fw_devlink=off clk_ignore_unused pd_ignore_unused regulator_ignore_unused panic=0 initcall_debug printk.time=1 swiotlb=2048 reset_devices rodata=on systemd.unit=multi-user.target systemd.show_status=1 pci=realloc'
"$kexec" -u 2>/dev/null || true
"$kexec" -c -l "$dir/Image" --dtb="$dir/board.dtb" --initrd="$dir/initramfs.cpio.gz" --append="$cmdline" || fail 'kexec load failed'
[ "$(cat /sys/kernel/kexec_loaded)" = 1 ] || fail 'kexec_loaded is not 1'
echo loaded >/run/tb371fc-linux612-r38.state
echo starting >"$dir/state"
echo 'TB371FC AUTOBOOT: payload verified; starting Linux 6.12 now.'
exec /run/tb371fc-rescue/execute-linux-6.12-r38
