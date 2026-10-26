#!/usr/bin/env bash
# R152 payload: R140 Image + R151 Wi-Fi DTB + initramfs = R149b (touch/KDE autostart)
# + Wi-Fi modules + r152 Wi-Fi service. The Wi-Fi credential (hashed PSK only) comes
# from D:/TB371FC-builds/private and is never stored in the repository.
set -euo pipefail
project="$(cd "$(dirname "$0")/.." && pwd)"
b149=/mnt/d/TB371FC-builds/r149b-autostart
w=/mnt/d/TB371FC-builds/r151-wifi
wpa=/mnt/d/TB371FC-builds/private/r152-wpa.conf
pkg=/mnt/d/TB371FC-builds/r152-wifi-autostart
cfg="$project/scripts/r152-config"
test ! -e "$pkg"
(cd "$b149"; grep -E " (Image|initramfs.cpio.gz)$" SHA256SUMS | sha256sum -c -)
test "$(sha256sum "$w/board.dtb" | cut -d' ' -f1)" = 1e6151687b740dd65a5a51e0a690b7f32ecc9399b868c238d8fae2f27776c5a6
(cd "$w/modules"; sha256sum -c SHA256SUMS --quiet)
grep -q '^\s*psk=[0-9a-f]\{64\}$' "$wpa"
mkdir -p "$pkg"
cp "$b149/Image" "$w/board.dtb" "$pkg/"
stage=$(mktemp -d /root/tb371fc/r152-initramfs.XXXXXX)
echo "$stage" > "$pkg/staging-path.txt"
(cd "$stage"; gzip -dc "$b149/initramfs.cpio.gz" | cpio -idmu --quiet)
ev="$stage/r129-config/r129-evidence.sh"
tail -1 "$ev" | grep -q '^/run/r130/busybox sh /run/r130/config/r149-install.sh$'
for k in michael_mic pwrseq-core pwrseq-qcom-wcn cfg80211 mac80211 ath qmi_helpers ath11k ath11k_pci pci-pwrctrl-core pci-pwrctrl-pwrseq phy-qcom-qmp-pcie; do
    test ! -e "$stage/r130-modules/$k.ko"
    cp "$w/modules/$k.ko" "$stage/r130-modules/"
done
cp "$cfg/r152-wifi.sh" "$cfg/r152-wifi.service" "$cfg/r152-install.sh" "$stage/r130-config/"
install -m 0600 "$wpa" "$stage/r130-config/r152-wpa.conf"
for f in r152-wifi.sh r152-install.sh; do sh -n "$stage/r130-config/$f"; done
printf '/run/r130/busybox sh /run/r130/config/r152-install.sh\n' >> "$ev"
sh -n "$ev"; tail -2 "$ev"
(cd "$stage"; find . -print0 | sort -z | cpio --null -o --format=newc --owner=0:0 --quiet | gzip -9n) > "$pkg/initramfs.cpio.gz"
cd "$pkg"
sha256sum Image board.dtb initramfs.cpio.gz > SHA256SUMS
tar -czf r152-payload.tar.gz Image board.dtb initramfs.cpio.gz
sha256sum r152-payload.tar.gz >> SHA256SUMS
cat SHA256SUMS
