#!/usr/bin/env bash
set -euo pipefail

base_dir=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r84-real-ram-map-dtb
out_dir=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r98-ufs-disabled-dtb
base=$base_dir/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram.dtb
dtb=$out_dir/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram-ufs-disabled.dtb
base_sha=c954a4d36e5bf25c2884bc83293222fd866697556c2fa2fc9f67dbcd85fbfcae

printf '%s  %s\n' "$base_sha" "$base" | sha256sum -c -
test ! -e "$out_dir" || { echo "Refusing to overwrite $out_dir" >&2; exit 1; }
mkdir -p "$out_dir"
cp "$base" "$dtb"

# UFS is not required by the RAM/initramfs bring-up path. Disable both the
# host and PHY to stop the circular -EPROBE_DEFER storm without touching any
# UFS media. The same policy is used by the audited TB371FC U-Boot stage-0 DT.
fdtput -t s "$dtb" /soc/ufshc@1d84000 status disabled
fdtput -t s "$dtb" /soc/phy@1d87000 status disabled

test "$(fdtget -t s "$dtb" /soc/ufshc@1d84000 status)" = disabled
test "$(fdtget -t s "$dtb" /soc/phy@1d87000 status)" = disabled
test "$(fdtget -t x "$dtb" /memory@80000000 reg | wc -w)" = 76

dtc -I dtb -O dts -o "$out_dir/base.dts" "$base" 2>"$out_dir/base-dtc.stderr"
dtc -I dtb -O dts -o "$out_dir/r98.dts" "$dtb" 2>"$out_dir/r98-dtc.stderr"
diff -u "$out_dir/base.dts" "$out_dir/r98.dts" >"$out_dir/semantic.diff" || true
changes=$(grep -E '^[+-]' "$out_dir/semantic.diff" | grep -Ev '^(---|\+\+\+)' || true)
test "$(printf '%s\n' "$changes" | sed '/^$/d' | wc -l)" = 4
test "$(printf '%s\n' "$changes" | grep -c '^-.*status = "okay";')" = 2
test "$(printf '%s\n' "$changes" | grep -c '^+.*status = "disabled";')" = 2

cat >"$out_dir/BUILD-INFO.txt" <<EOF
TB371FC Linux 6.12 r98 DTB: full r84 RAM map with UFS safely disabled

Base DTB SHA-256: $base_sha

Semantic changes are exactly:
  /soc/ufshc@1d84000 status = "disabled"
  /soc/phy@1d87000   status = "disabled"

Reason: r96 reached driver probe and remained alive, but continuously retried
ufshcd-qcom after OPP parsing returned -EPROBE_DEFER (-517). Internal UFS is
not needed for the RAM/initramfs bring-up and must not be written. The exact
19-range real-RAM property remains unchanged (76 cells).
EOF

( cd "$out_dir"; sha256sum "$(basename "$dtb")" BUILD-INFO.txt semantic.diff >SHA256SUMS; sha256sum -c SHA256SUMS )
sha256sum "$dtb"
