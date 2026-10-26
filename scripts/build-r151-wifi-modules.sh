#!/usr/bin/env bash
# R151: Wi-Fi (QCA6390 over PCIe0) modules for the R130/R140..R150 kernel
# 6.12.30-tb371fc-r130-usb2-late+. In-tree modules (=m in its .config) are
# built with M=; the QMP PCIe PHY (not configured) is built as an external
# module from a copy of drivers/phy/qualcomm. The original r130 output is not touched.
set -euo pipefail
src=/root/tb371fc/linux-6.12-donor-r118
base=/root/tb371fc/build-6.12-r130-usb2-late
out=/root/tb371fc/build-6.12-r151-wifi
pkg=/mnt/d/TB371FC-builds/r151-wifi/modules
phy=/root/tb371fc/r151-qmp-pcie-phy
ref=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r130-usb2-late/dwc3-qcom.ko
if [ "${1:-}" != --resume ]; then
    test ! -e "$out"; test ! -e "$pkg"; test ! -e "$phy"
    cp -a "$base" "$out"
    mkdir -p "$pkg" "$phy"
    cp "$src"/drivers/phy/qualcomm/phy-qcom-qmp*.h "$src"/drivers/phy/qualcomm/phy-qcom-qmp-pcie.c "$phy/"
    printf 'obj-m += phy-qcom-qmp-pcie.o\n' > "$phy/Kbuild"
fi
k() { make -C "$src" O="$out" ARCH=arm64 LLVM=-18 -j8 "$@"; }
want="net/wireless/cfg80211.ko net/mac80211/mac80211.ko drivers/net/wireless/ath/ath.ko
drivers/net/wireless/ath/ath11k/ath11k.ko drivers/net/wireless/ath/ath11k/ath11k_pci.ko
drivers/power/sequencing/pwrseq-core.ko drivers/power/sequencing/pwrseq-qcom-wcn.ko
drivers/pci/pwrctrl/pci-pwrctrl-core.ko drivers/pci/pwrctrl/pci-pwrctrl-pwrseq.ko
drivers/soc/qcom/qmi_helpers.ko"
echo "== in-tree modules (one make call so modpost resolves cross-module symbols)"
k $want > "$pkg/build-intree.log" 2>&1 || { tail -30 "$pkg/build-intree.log"; exit 1; }
for m in $want; do
    f="$out/$m"; [ -s "$f" ] || f=$(find "$out/$(dirname $m)" -maxdepth 1 -name "$(basename $m)" | head -1)
    [ -s "$f" ] || { echo "MISSING $m"; ls "$out/$(dirname $m)"/*.ko 2>/dev/null; exit 1; }
    cp "$f" "$pkg/"
done
echo "== qmp pcie phy (external)"
k M="$phy" modules > "$pkg/build-qmp-pcie-phy.log" 2>&1 || { tail -30 "$pkg/build-qmp-pcie-phy.log"; exit 1; }
cp "$phy/phy-qcom-qmp-pcie.ko" "$pkg/"
v=$(modinfo -F vermagic "$ref")
for f in "$pkg"/*.ko; do [ "$(modinfo -F vermagic "$f")" = "$v" ] || { echo "VERMAGIC $f"; exit 1; }; done
(cd "$pkg"; for f in *.ko; do printf '%s depends=%s\n' "$f" "$(modinfo -F depends $f)"; done; sha256sum *.ko > SHA256SUMS)
cat "$pkg/SHA256SUMS"
