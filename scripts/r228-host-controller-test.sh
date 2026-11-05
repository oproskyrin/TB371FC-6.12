#!/bin/sh
# Temporary host-controller test, NOT a CC/PD or VBUS source driver.
set -eu
case "${1:-}" in
 hub-connected-no-pd) rollback=180 ;;
 hub-powered-source-off)
  # Externally powered hub, only after exact read-only PMIC checks. This
  # changes the DATA role only; it must not source power into the PD input.
  test ! -d /sys/module/qcom_pmic_tcpm
  test ! -d /sys/module/qcom_usb_vbus_regulator
  test "$(sha256sum /run/r227-typec-status.ko | cut -d ' ' -f1)" = 400c48ea896a43974c5f171615148882f728913b8e045b328d0dd51546e667e5
  insmod /run/r227-typec-status.ko
  rmmod r227_typec_status
  snapshot=$(dmesg | grep R227 | tail -23)
  printf '%s\n' "$snapshot" | grep -q 'R227 reg=1140 value=00'
  printf '%s\n' "$snapshot" | grep -q 'R227 reg=1544 value=12'
  rollback=600 ;;
 hub-charging-sink)
  test -d /sys/module/r231_charge_keepalive
  test "$(cat /sys/module/r231_charge_keepalive/parameters/active)" = Y
  test "$(cat /sys/module/r231_charge_keepalive/parameters/fault)" = 0
  test "$(cat /sys/module/r231_charge_keepalive/parameters/pets)" -ge 5
  test ! -d /sys/module/qcom_pmic_tcpm
  test ! -d /sys/module/qcom_usb_vbus_regulator
  test "$(sha256sum /run/r227-typec-status.ko | cut -d ' ' -f1)" = 400c48ea896a43974c5f171615148882f728913b8e045b328d0dd51546e667e5
  insmod /run/r227-typec-status.ko
  rmmod r227_typec_status
  snapshot=$(dmesg | grep R227 | tail -23)
  printf '%s\n' "$snapshot" | grep -q 'R227 reg=1140 value=00'
  printf '%s\n' "$snapshot" | grep -q 'R227 reg=1544 value=02'
  rollback=300 ;;
 *) exit 1 ;;
esac
grep -qw tb371fc.r228 /proc/cmdline
test "$(tr -d '\000' </proc/device-tree/chosen/tb371fc,host-test)" = r228-otg
test -z "$(find /sys/class/typec -maxdepth 1 -name 'port*' -print -quit)"
# Management MUST be over Wi-Fi, not the USB link being taken down.
set -- ${SSH_CONNECTION:?SSH session identity required}
server=$3
ip -4 -o addr show dev wlp1s0 | grep -Fq " $server/"
test -f /run/r228-return-device.sh
mode=/sys/kernel/debug/usb/a600000.usb/mode
test "$(cat "$mode")" = device
g=/sys/kernel/config/usb_gadget/tb371fc-r130
test "$(cat "$g/UDC")" = a600000.usb
systemd-run --unit=r228-device-rollback --on-active="${rollback}s" /bin/sh /run/r228-return-device.sh
printf '\n' > "$g/UDC"
printf 'host\n' > "$mode"
sleep 3
test "$(cat "$mode")" = host
lsusb -t
ls /sys/bus/platform/devices/*xhci* /sys/bus/usb/devices/usb* 2>/dev/null || true
echo "R228 HOST controller selected; no VBUS/PD changes, automatic DEVICE return in${rollback}s"
