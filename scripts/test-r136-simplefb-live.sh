#!/bin/sh
set -eu
dir=/run/r136
dev=9c000000.framebuffer
base=/sys/devices/platform/$dev
[ "$(uname -r)" = 6.12.30-tb371fc-r134-panel+ ]
[ "$(cat /proc/sys/kernel/random/boot_id)" = 1d4ea8c5-929e-4186-9c05-6144302b15f7 ]
[ "$(sha256sum "$dir/tb371fc_simplefb.ko" | awk '{print $1}')" = 737e26174964c5c81ec2f94f30516023a0112ae2db9b791a316c0fd4285d560f ]
[ "$(basename "$(readlink "$base/driver")")" = simple-framebuffer ]
test ! -d /sys/module/dispcc_sm8250
test ! -d /sys/module/tb371fc_simplefb
for prop in clocks power-domains mdss-supply; do test ! -e "$base/of_node/$prop"; done
cat /proc/sys/kernel/random/boot_id /proc/uptime > "$dir/identity-before.txt"
dmesg > "$dir/dmesg-before.txt"
cat /sys/kernel/debug/dri/0/state > "$dir/drm-before.txt"
rollback() {
    code=$?
    trap - EXIT
    if [ "$code" != 0 ]; then
        printf 'R136: failed rc=%s; restoring original simpledrm binding\n' "$code"
        printf simple-framebuffer > "$base/driver_override"
        if [ ! -L "$base/driver" ]; then
            printf '%s' "$dev" > /sys/bus/platform/drivers/simple-framebuffer/bind || true
        fi
    fi
    printf '\n' > "$base/driver_override"
    printf 1 > /sys/class/vtconsole/vtcon1/bind || true
    dmesg > "$dir/dmesg-after.txt"
    exit "$code"
}
trap rollback EXIT
printf 0 > /sys/class/vtconsole/vtcon1/bind
printf '%s' "$dev" > /sys/bus/platform/drivers/simple-framebuffer/unbind
printf tb371fc-simplefb-control > "$base/driver_override"
timeout 20 insmod "$dir/tb371fc_simplefb.ko"
[ "$(basename "$(readlink "$base/driver")")" = tb371fc-simplefb-control ]
[ "$(cat /sys/class/graphics/fb0/name)" = simple ]
printf 1 > /sys/class/vtconsole/vtcon1/bind
TERM=linux setterm --blank 0 --powerdown 0 < /dev/tty1 > /dev/tty1 || true
printf '\033[H\033[2JR136: DIRECT SIMPLEFB CONSOLE\nARCH 6.12 USB SSH ALIVE\nNo native DSI or panel reset\n' > /dev/tty1
cat /proc/fb
readlink "$base/driver"
systemctl is-active r130-sshd.service
cat /proc/sys/kernel/random/boot_id /proc/uptime
exit 0
