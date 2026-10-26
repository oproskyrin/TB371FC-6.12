#!/usr/bin/env bash
set -euo pipefail

base_dir=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r100-headless-microsd-no-rpmh-opp-dtb
out_dir=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r101-headless-microsd-inherited-power-dtb
base=$base_dir/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram-ufs-disabled-no-usb1-no-mmc-rpmh-opp.dtb
dtb=$out_dir/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram-ufs-disabled-no-usb1-mmc-inherited-power.dtb
base_sha=d5364d74a8dc37a934fc40e13764bc0f546615b8fdf6cc29a6838c5944869b13

printf '%s  %s\n' "$base_sha" "$base" | sha256sum -c -
test ! -e "$out_dir" || { echo "Refusing to overwrite $out_dir" >&2; exit 1; }
mkdir -p "$out_dir"
cp "$base" "$dtb"

# The r100 test proved SDHCI still defers because these remaining suppliers
# are also children of the RPMh RSC that times out after warm kexec. The 4.19
# first stage reads this exact card immediately before handoff, so retain the
# inherited rail state and use the already-described fixed 38.4 MHz board XO.
fdtput -d "$dtb" /soc/mmc@8804000 vmmc-supply
fdtput -d "$dtb" /soc/mmc@8804000 vqmmc-supply
fdtput -t x "$dtb" /soc/mmc@8804000 clocks 0x30 0x89 0x30 0x8a 0xf7

! fdtget "$dtb" /soc/mmc@8804000 power-domains >/dev/null 2>&1
! fdtget "$dtb" /soc/mmc@8804000 operating-points-v2 >/dev/null 2>&1
! fdtget "$dtb" /soc/mmc@8804000 vmmc-supply >/dev/null 2>&1
! fdtget "$dtb" /soc/mmc@8804000 vqmmc-supply >/dev/null 2>&1
test "$(fdtget -t x "$dtb" /soc/mmc@8804000 clocks)" = "30 89 30 8a f7"
test "$(fdtget -t s "$dtb" /soc/mmc@8804000 clock-names)" = "iface core xo"
test "$(fdtget -t x "$dtb" /clocks/xo-board clock-frequency)" = 249f000
test "$(fdtget -t x "$dtb" /soc/mmc@8804000 max-frequency)" = 17d7840
test "$(fdtget -t x "$dtb" /soc/mmc@8804000 bus-width)" = 4
test "$(fdtget -t s "$dtb" /soc/ufshc@1d84000 status)" = disabled
test "$(fdtget -t s "$dtb" /soc/usb@a6f8800 status)" = disabled
test "$(fdtget -t x "$dtb" /memory@80000000 reg | wc -w)" = 76

dtc -I dtb -O dts -o "$out_dir/base.dts" "$base" 2>"$out_dir/base-dtc.stderr"
dtc -I dtb -O dts -o "$out_dir/r101.dts" "$dtb" 2>"$out_dir/r101-dtc.stderr"
diff -u "$out_dir/base.dts" "$out_dir/r101.dts" >"$out_dir/semantic.diff" || true
changes=$(grep -E '^[+-]' "$out_dir/semantic.diff" | grep -Ev '^(---|\+\+\+)' || true)
test "$(printf '%s\n' "$changes" | sed '/^$/d' | wc -l)" = 4
test "$(printf '%s\n' "$changes" | grep -c '^-.*vmmc-supply =')" = 1
test "$(printf '%s\n' "$changes" | grep -c '^-.*vqmmc-supply =')" = 1
test "$(printf '%s\n' "$changes" | grep -c '^-.*clocks = <0x30 0x89 0x30 0x8a 0x2e 0x00>;')" = 1
test "$(printf '%s\n' "$changes" | grep -c '^+.*clocks = <0x30 0x89 0x30 0x8a 0xf7>;')" = 1

cat >"$out_dir/BUILD-INFO.txt" <<EOF
TB371FC Linux 6.12 r101 DTB: SDHCI inherited rails and fixed board XO

Base DTB SHA-256: $base_sha

Changes from r100 are exactly:
  remove /soc/mmc@8804000/vmmc-supply
  remove /soc/mmc@8804000/vqmmc-supply
  replace only the MMC xo clock provider: RPMh clock 0 -> xo-board fixed clock

The first-stage 4.19 kernel uses the same card immediately before kexec, so
the rails are already active. Conservative 25 MHz, four-bit, no-1.8-V mode,
card-detect and redriver GPIO remain unchanged. UFS/USB1 remain disabled.
EOF

( cd "$out_dir"; sha256sum "$(basename "$dtb")" BUILD-INFO.txt semantic.diff >SHA256SUMS; sha256sum -c SHA256SUMS )
sha256sum "$dtb"
