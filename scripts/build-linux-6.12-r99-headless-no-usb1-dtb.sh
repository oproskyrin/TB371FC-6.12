#!/usr/bin/env bash
set -euo pipefail

base_dir=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r98-ufs-disabled-dtb
out_dir=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r99-headless-no-usb1-dtb
base=$base_dir/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram-ufs-disabled.dtb
dtb=$out_dir/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram-ufs-disabled-no-usb1.dtb
base_sha=ae49070f0e18925de03eb1933a995d7603c9dabb590ef98a097858cb9127c9a7

printf '%s  %s\n' "$base_sha" "$base" | sha256sum -c -
test ! -e "$out_dir" || { echo "Refusing to overwrite $out_dir" >&2; exit 1; }
mkdir -p "$out_dir"
cp "$base" "$dtb"

# r98 proved that disabling UFS removes its deferred-probe storm. The next
# independent storm is the USB1 DWC3 child repeatedly attaching to SMMU group
# 8. Disable the complete QCOM wrapper for this headless milestone so that no
# child or PHY consumer can probe. USB will be repaired separately after the
# initramfs/userspace path has been proven.
fdtput -t s "$dtb" /soc/usb@a6f8800 status disabled

test "$(fdtget -t s "$dtb" /soc/ufshc@1d84000 status)" = disabled
test "$(fdtget -t s "$dtb" /soc/phy@1d87000 status)" = disabled
test "$(fdtget -t s "$dtb" /soc/usb@a6f8800 status)" = disabled
test "$(fdtget -t x "$dtb" /memory@80000000 reg | wc -w)" = 76

dtc -I dtb -O dts -o "$out_dir/base.dts" "$base" 2>"$out_dir/base-dtc.stderr"
dtc -I dtb -O dts -o "$out_dir/r99.dts" "$dtb" 2>"$out_dir/r99-dtc.stderr"
diff -u "$out_dir/base.dts" "$out_dir/r99.dts" >"$out_dir/semantic.diff" || true
changes=$(grep -E '^[+-]' "$out_dir/semantic.diff" | grep -Ev '^(---|\+\+\+)' || true)
test "$(printf '%s\n' "$changes" | sed '/^$/d' | wc -l)" = 2
test "$(printf '%s\n' "$changes" | grep -c '^-.*status = "okay";')" = 1
test "$(printf '%s\n' "$changes" | grep -c '^+.*status = "disabled";')" = 1

cat >"$out_dir/BUILD-INFO.txt" <<EOF
TB371FC Linux 6.12 r99 DTB: r98 plus USB1 disabled for headless boot

Base DTB SHA-256: $base_sha

The only semantic change from r98 is:
  /soc/usb@a6f8800 status = "disabled"

Reason: r98 removed the UFS/OPP storm and reached the next blocker, where
dwc3 a600000.usb was re-added to IOMMU group 8 roughly every 64 ms. USB1 is
not required to prove initramfs/headless userspace. This build deliberately
trades USB diagnostics for forward boot progress; USB will be fixed later.
The full 19-range RAM map and the r98 UFS safety policy remain unchanged.
EOF

( cd "$out_dir"; sha256sum "$(basename "$dtb")" BUILD-INFO.txt semantic.diff >SHA256SUMS; sha256sum -c SHA256SUMS )
sha256sum "$dtb"
