#!/usr/bin/env bash
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
src=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r108-headless-microsd-redriver-hog-poll-dtb/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram-ufs-disabled-no-usb1-mmc-no-iommu-pio-redriver-hog-poll.dtb
out=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r112-headless-microsd-inherited-1v8-dtb
dtb=$out/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram-ufs-disabled-no-usb1-mmc-no-iommu-pio-redriver-hog-inherited-1v8.dtb

bash "$project/scripts/build-linux-6.12-r108-headless-microsd-redriver-hog-poll-dtb.sh"
test -s "$src"
test ! -e "$out" || { echo "Refusing to overwrite $out" >&2; exit 1; }
mkdir -p "$out"
cp --reflink=auto "$src" "$dtb"

# Live first-stage evidence shows that the working downstream 4.19 host leaves
# pm8150a_l6 (SD I/O) at 1.808 V and the card in SDR104 immediately before
# kexec. r108 inherited that electrical state but advertised no-1-8-v to the
# incoming MMC core. Remove only this contradictory capability restriction;
# retain the dependency-free, PIO-only, 25 MHz, GPIO75-hog r108 baseline.
fdtput -d "$dtb" /soc/mmc@8804000 no-1-8-v

! fdtget "$dtb" /soc/mmc@8804000 no-1-8-v >/dev/null 2>&1
test "$(fdtget -t x "$dtb" /soc/mmc@8804000 max-frequency)" = 17d7840
test "$(fdtget -t x "$dtb" /soc/mmc@8804000 bus-width)" = 4
fdtget "$dtb" /soc/mmc@8804000 broken-cd >/dev/null
test "$(fdtget -t x "$dtb" /soc/mmc@8804000 sdhci-caps-mask)" = "0 480000"
for prop in vmmc-supply vqmmc-supply cd-gpios pinctrl-names pinctrl-0 pinctrl-1 iommus redriver-power-gpios; do
  ! fdtget "$dtb" /soc/mmc@8804000 "$prop" >/dev/null 2>&1
done
test "$(fdtget -t x "$dtb" /soc/pinctrl@f100000/sd-redriver-hog gpios)" = "4b 0"
fdtget "$dtb" /soc/pinctrl@f100000/sd-redriver-hog output-high >/dev/null
test "$(fdtget -t s "$dtb" /soc/ufshc@1d84000 status)" = disabled
test "$(fdtget -t s "$dtb" /soc/usb@a6f8800 status)" = disabled

dtc -I dtb -O dts -o "$out/r108.dts" "$src" 2>"$out/r108-dtc.stderr"
dtc -I dtb -O dts -o "$out/r112.dts" "$dtb" 2>"$out/r112-dtc.stderr"
diff -u "$out/r108.dts" "$out/r112.dts" >"$out/semantic.diff" || true
changes=$(grep -E '^[+-]' "$out/semantic.diff" | grep -Ev '^(---|\+\+\+)' || true)
test "$(printf '%s\n' "$changes" | sed '/^$/d' | wc -l)" = 1
test "$(printf '%s\n' "$changes" | grep -c '^-.*no-1-8-v;')" = 1

cat >"$out/BUILD-INFO.txt" <<EOF
TB371FC Linux 6.12 r112 DTB: inherit the live 1.8-V SD I/O state

Only delta from the hardware-proven r108 DTB: remove no-1-8-v from
/soc/mmc@8804000. Live first-stage 4.19 measurements immediately before kexec:
pm8150a_l9=2.950 V, pm8150a_l6=1.808 V, GPIO14 card-present, GPIO75 redriver-on,
and ED2S5 card initialized as SDR104. r108 incorrectly told Linux 6.12 to use
3.3-V-only signalling while inheriting this 1.8-V electrical state.

PIO-only, 25 MHz, broken-CD polling, provider-local GPIO75 hog, UFS disabled,
USB1 disabled and no Android mounts are retained exactly.
EOF

( cd "$out"; sha256sum "$(basename "$dtb")" BUILD-INFO.txt semantic.diff >SHA256SUMS; sha256sum -c SHA256SUMS )
sha256sum "$dtb"
