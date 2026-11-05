#!/bin/sh
# R240 RX cleanup in R238 PD-only harness; RAM boot, no persistent installation.
set -eu
case "$(uname -r)" in 4.19.157*) ;; *) echo 'Wrong boot stage'; exit 1;; esac
bb=/run/tb371fc-rescue/busybox
dir=/run/r240-test
mkdir -p "$dir"
"$bb" tar -xzf /run/r238-pd-ram-payload.tar.gz -C "$dir"
check() { test "$("$bb" sha256sum "$dir/$1" | "$bb" awk '{print $1}')" = "$2"; }
check Image 7a59c7b2931c8e8925446a3cec5432a0912d5f0e3f9365058de2492ad6d0d157
check board.dtb 61d055cc0a1d63413ebe345b2c305f165230d5a156d20c66e89026468d3173e2
check initramfs.cpio.gz 929b3e5bc933738c775af26bd99a82d15fac3e1da94091bbb7c3c7f4f67c7de4
check cmdline.txt 0155793ace845bd153f51e198b19cca02a4573d9d658d5be95f6e863183feaef
cmdline=$(cat "$dir/cmdline.txt")
for flag in console=tty0 rdinit=/init root=/dev/ram0 fw_devlink=off regulator_ignore_unused reset_devices tb371fc.sd150 tb371fc.r226 tb371fc.usb3test tb371fc.r238 systemd.mask=r231-charge-keepalive.service; do
    printf '%s\n' "$cmdline" | grep -qw "$flag" || { echo "Missing critical flag: $flag"; exit 1; }
done
/run/tb371fc-rescue/kexec -u 2>/dev/null || true
/run/tb371fc-rescue/kexec -c -l "$dir/Image" --dtb="$dir/board.dtb" --initrd="$dir/initramfs.cpio.gz" --append="$cmdline"
test "$(cat /sys/kernel/kexec_loaded)" = 1
echo loaded > /run/tb371fc-linux612-r38.state
echo 'R240 RX cleanup; PD MANUAL ONLY; R226 unchanged'
exec /run/tb371fc-rescue/execute-linux-6.12-r38
