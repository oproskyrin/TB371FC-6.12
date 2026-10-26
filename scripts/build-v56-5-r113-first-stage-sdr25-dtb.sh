#!/usr/bin/env bash
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
v565=/mnt/d/TB371FC-builds/arch-development-loader-v56-5-r2-community-simplefb-qca6390-kde-kexec-cpu-hotplug-safe
source_dtb=$v565/dtb-v56-5.img
out=/mnt/d/TB371FC-builds/arch-development-loader-v56-5-r113-first-stage-sdr25-dtb
patched=$out/dtb-v56-5-r113-first-stage-sdr25.img
node=/soc/sdhci@8804000

test -s "$source_dtb"
mkdir -p "$out"
extract=$(mktemp -d)
verify=$(mktemp -d)
work=$(mktemp -d)
trap 'rm -rf -- "$extract" "$verify" "$work"' EXIT

python3 "$project/scripts/extract-concatenated-dtb.py" "$source_dtb" "$extract" \
  >"$out/source-layout.txt"
cp --reflink=auto "$source_dtb" "$work/current.img"

# Every real base-DTB entry carries the same downstream SDHCI policy. Patch all
# three so the selected SKU cannot retain SDR50/DDR50/SDR104 by selecting a
# different base entry. The tiny fourth trailer entry is preserved verbatim.
for index in 00 01 02; do
  entry="$work/entry-$index-sdr25.dtb"
  next="$work/next-$index.img"
  cp --reflink=auto "$extract/entry-$index.dtb" "$entry"
  fdtput -t s "$entry" "$node" qcom,bus-speed-mode SDR12 SDR25
  test "$(fdtget -t s "$entry" "$node" qcom,bus-speed-mode)" = 'SDR12 SDR25'
  python3 "$project/scripts/replace-concatenated-dtb-entry.py" \
    "$work/current.img" "$((10#$index))" "$entry" "$next"
  mv "$next" "$work/current.img"
done
cp --reflink=auto "$work/current.img" "$patched"

python3 "$project/scripts/extract-concatenated-dtb.py" "$patched" "$verify" \
  >"$out/patched-layout.txt"
for index in 00 01 02; do
  test "$(fdtget -t s "$verify/entry-$index.dtb" "$node" qcom,bus-speed-mode)" = \
    'SDR12 SDR25'
done
cmp "$extract/entry-03.dtb" "$verify/entry-03.dtb"
sha256sum "$source_dtb" "$patched" >"$out/SHA256SUMS"
cat "$out/SHA256SUMS"
