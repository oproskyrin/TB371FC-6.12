#!/usr/bin/env bash
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
template="$project/scripts/build-v56-6-controlled-linux-6.12-r104-sdhci-diagnostics-fwdevlink-off-transport-r2.sh"
generated=$(mktemp)
trap 'rm -f -- "$generated"' EXIT
bash "$project/scripts/build-linux-6.12-r109-headless-microsd-redriver-hog-usb-ncm-dtb.sh"

python3 - "$template" "$generated" <<'PYEOF'
import sys
src, dst = sys.argv[1:3]
text = open(src, encoding='utf-8').read()
assert text.count('r104') == 7
text = text.replace('r104', 'r110')
assert text.count('R104') == 3
text = text.replace('R104', 'R110')
old_dtb = '/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r101-headless-microsd-inherited-power-dtb/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram-ufs-disabled-no-usb1-mmc-inherited-power.dtb'
new_dtb = '/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r109-headless-microsd-redriver-hog-usb-ncm-dtb/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram-ufs-disabled-mmc-pio-redriver-hog-usb-ncm.dtb'
assert text.count(old_dtb) == 1
text = text.replace(old_dtb, new_dtb)
old_info = '''Linux 6.12 payload: exact r70 layout-preserving Image and exact r101
headless DTB. The second-stage command line contains exactly one fw_devlink=off
token and no permissive token. The r110 inner initramfs uses BusyBox tail and
discovers the actual 8804000.mmc sysfs path before reporting device links.'''
new_info = '''Linux 6.12 payload: exact r70 Image and exact r109 live-log DTB.
r110 changes only initramfs diagnostics: USB/DWC3/UDC, GPIO and MMC state are
printed last with console noise reduced. This identifies why the r109 NCM
gadget did not enumerate while preserving every r108/r109 hardware setting.'''
assert text.count(old_info) == 1
text = text.replace(old_info, new_info)
text = text.replace("echo 'USB is intentionally disabled in this headless test.' >&2",
                    "echo 'USB NCM live-log channel requested on 169.254.77.2:2323.' >&2")
needle = "\\techo '=== R110 SDHCI DIAGNOSTICS END ===' >&2\n\\techo 'USB NCM live-log channel requested on 169.254.77.2:2323.' >&2"
extra = '''\tdmesg -n 1 2>/dev/null || true
\techo '--- R110 USB DWC3 filtered dmesg ---' >&2
\tdmesg 2>/dev/null | grep -iE 'usb|dwc3|gadget|udc|a6f8800|a600000|qmp|qusb|phy' | busybox tail -n 120 >&2 || true
\techo '--- R110 UDC and gadget sysfs ---' >&2
\tls -la /sys/class/udc >&2 2>/dev/null || true
\tfor udc in /sys/class/udc/*; do
\t\t[ -e "$udc" ] || continue
\t\techo "UDC=$udc" >&2
\t\tls -la "$udc" >&2 2>/dev/null || true
\tdone
\tfind /sys/devices -type d \( -name 'a6f8800.usb' -o -name 'a600000.usb' \) 2>/dev/null | while read -r usbdev; do
\t\techo "USBDEV=$usbdev" >&2
\t\tls -la "$usbdev" >&2 2>/dev/null || true
\tdone
\techo '--- R110 GPIO 75 state ---' >&2
\tgrep -E 'gpio-75|tb371fc-sd-redriver' /sys/kernel/debug/gpio >&2 2>/dev/null || true
\techo '=== R110 USB LIVE-LOG DIAGNOSTICS END ===' >&2
\techo 'USB NCM live-log channel requested on 169.254.77.2:2323.' >&2'''
assert text.count(needle) == 1
text = text.replace(needle, extra)
open(dst, 'w', encoding='utf-8', newline='\n').write(text)
PYEOF
chmod 0755 "$generated"
bash "$generated"
