#!/bin/sh
set -eu
bb=/run/r130/busybox
dir=/run/r130
mark() { printf 'R130 USB: %s\n' "$*" | tee -a "$dir/steps.txt"; }
diagnostics() {
    rc=$?
    trap - EXIT
    set +e
    dmesg > "$dir/dmesg.txt"
    cat /sys/kernel/debug/devices_deferred > "$dir/deferred.txt"
    ls -la /sys/class/udc > "$dir/udc.txt"
    ip address > "$dir/network.txt"
    if [ "$rc" -ne 0 ]; then
        mark "STOP rc=$rc; Arch remains running; logs in /run/r130"
        dmesg | grep -iE 'usb|dwc3|88e3000|phy|a6f8800|a600000|iommu|regulator' | tail -n 35
        cat "$dir/deferred.txt"
    fi
    exit "$rc"
}
trap diagnostics EXIT
mark 'loading USB2 PHY module'
"$bb" timeout 15 "$bb" insmod "$dir/modules/phy-qcom-snps-femto-v2.ko"
mark 'loading Qualcomm DWC3 module'
"$bb" timeout 20 "$bb" insmod "$dir/modules/dwc3-qcom.ko"
udc=
for n in 1 2 3 4 5; do
    for entry in /sys/class/udc/*; do
        [ -e "$entry" ] || continue
        udc=${entry##*/}
        break
    done
    [ -z "$udc" ] || break
    sleep 1
done
[ -n "$udc" ] || { mark 'no UDC registered'; exit 1; }
mark "UDC=$udc; creating ACM/NCM gadget"
mountpoint -q /sys/kernel/config || mount -t configfs configfs /sys/kernel/config
g=/sys/kernel/config/usb_gadget/tb371fc-r130
mkdir "$g"
printf '0x1d6b\n' > "$g/idVendor"
printf '0x0104\n' > "$g/idProduct"
printf '0x0200\n' > "$g/bcdUSB"
printf '0x0130\n' > "$g/bcdDevice"
printf '0xef\n' > "$g/bDeviceClass"
printf '0x02\n' > "$g/bDeviceSubClass"
printf '0x01\n' > "$g/bDeviceProtocol"
mkdir "$g/strings/0x409" "$g/configs/c.1" "$g/configs/c.1/strings/0x409"
printf 'TB371FC-R130-USB2\n' > "$g/strings/0x409/serialnumber"
printf 'TB371FC Linux development\n' > "$g/strings/0x409/manufacturer"
printf 'R130 USB2 ACM NCM\n' > "$g/strings/0x409/product"
printf 'ACM + NCM\n' > "$g/configs/c.1/strings/0x409/configuration"
printf '250\n' > "$g/configs/c.1/MaxPower"
mkdir "$g/functions/acm.usb0" "$g/functions/ncm.usb0"
printf '%s\n' 'r130usb%d' > "$g/functions/ncm.usb0/ifname"
printf '02:37:1f:13:00:02\n' > "$g/functions/ncm.usb0/dev_addr"
printf '02:37:1f:13:00:01\n' > "$g/functions/ncm.usb0/host_addr"
ln -s "$g/functions/acm.usb0" "$g/configs/c.1/acm.usb0"
ln -s "$g/functions/ncm.usb0" "$g/configs/c.1/ncm.usb0"
mark 'binding gadget to UDC'
"$bb" timeout 15 sh -c 'printf "%s\n" "$1" > "$2"' bind "$udc" "$g/UDC"
mark 'UDC bind returned'
for n in 1 2 3 4 5; do
    [ -e /sys/class/net/r130usb0 ] && break
    sleep 1
done
ip link set r130usb0 up
ip address replace 172.31.77.2/30 dev r130usb0
cp "$dir/config/udhcpd.conf" "$dir/udhcpd.conf"
"$bb" udhcpd -f "$dir/udhcpd.conf" > "$dir/udhcpd.log" 2>&1 &
printf '%s\n' "$!" > "$dir/udhcpd-launch.pid"
systemctl --no-block start r130-sshd.service
systemctl --no-block start serial-getty@ttyGS0.service
mark 'gadget active; SSH planned on 172.31.77.2:2222; host DHCP lease .1; no gateway'
