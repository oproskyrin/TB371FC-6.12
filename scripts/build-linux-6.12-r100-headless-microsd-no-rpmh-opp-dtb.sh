#!/usr/bin/env bash
set -euo pipefail

base_dir=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r99-headless-no-usb1-dtb
out_dir=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r100-headless-microsd-no-rpmh-opp-dtb
base=$base_dir/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram-ufs-disabled-no-usb1.dtb
dtb=$out_dir/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram-ufs-disabled-no-usb1-no-mmc-rpmh-opp.dtb
base_sha=990014cda31d6d6178f72b592216edae88c1bc32c75d524b88cb00bc0022543b

printf '%s  %s\n' "$base_sha" "$base" | sha256sum -c -
test ! -e "$out_dir" || { echo "Refusing to overwrite $out_dir" >&2; exit 1; }
mkdir -p "$out_dir"
cp "$base" "$dtb"

# r99 reaches initramfs, but RPMh RSC times out after warm kexec and leaves
# SDHCI waiting forever for its RPMh power-domain/required-OPP supplier.
# The outgoing 4.19 loader already powered and used this card. Keep the proven
# conservative 25 MHz, four-bit, no-1.8-V board wiring, but stop SDHCI from
# attaching to the unavailable RPMh performance domain for this headless gate.
fdtput -d "$dtb" /soc/mmc@8804000 power-domains
fdtput -d "$dtb" /soc/mmc@8804000 operating-points-v2

! fdtget "$dtb" /soc/mmc@8804000 power-domains >/dev/null 2>&1
! fdtget "$dtb" /soc/mmc@8804000 operating-points-v2 >/dev/null 2>&1
test "$(fdtget -t s "$dtb" /soc/mmc@8804000 status)" = okay
test "$(fdtget -t x "$dtb" /soc/mmc@8804000 max-frequency)" = 17d7840
test "$(fdtget -t x "$dtb" /soc/mmc@8804000 bus-width)" = 4
test "$(fdtget -t s "$dtb" /soc/ufshc@1d84000 status)" = disabled
test "$(fdtget -t s "$dtb" /soc/phy@1d87000 status)" = disabled
test "$(fdtget -t s "$dtb" /soc/usb@a6f8800 status)" = disabled
test "$(fdtget -t x "$dtb" /memory@80000000 reg | wc -w)" = 76

dtc -I dtb -O dts -o "$out_dir/base.dts" "$base" 2>"$out_dir/base-dtc.stderr"
dtc -I dtb -O dts -o "$out_dir/r100.dts" "$dtb" 2>"$out_dir/r100-dtc.stderr"
diff -u "$out_dir/base.dts" "$out_dir/r100.dts" >"$out_dir/semantic.diff" || true
changes=$(grep -E '^[+-]' "$out_dir/semantic.diff" | grep -Ev '^(---|\+\+\+)' || true)
test "$(printf '%s\n' "$changes" | sed '/^$/d' | wc -l)" = 2
test "$(printf '%s\n' "$changes" | grep -c '^-.*power-domains =')" = 1
test "$(printf '%s\n' "$changes" | grep -c '^-.*operating-points-v2 =')" = 1
test "$(printf '%s\n' "$changes" | grep -c '^+')" = 0

cat >"$out_dir/BUILD-INFO.txt" <<EOF
TB371FC Linux 6.12 r100 DTB: r99 headless boot plus SDHCI RPMh bypass

Base DTB SHA-256: $base_sha

The only semantic changes from r99 are removal of these properties from
/soc/mmc@8804000:
  power-domains
  operating-points-v2

Reason: r99 completed kernel boot and entered initramfs, but RPMh RSC failed
with -ETIMEDOUT (-110), leaving the SDHCI supplier dependency deferred and
/dev/mmcblk0p1 absent. The 25 MHz, four-bit, 3.3-V-only card wiring, supplies,
GPIOs and redriver remain unchanged. UFS and USB1 remain disabled, and the
full 19-range real-RAM map is unchanged.
EOF

( cd "$out_dir"; sha256sum "$(basename "$dtb")" BUILD-INFO.txt semantic.diff >SHA256SUMS; sha256sum -c SHA256SUMS )
sha256sum "$dtb"
