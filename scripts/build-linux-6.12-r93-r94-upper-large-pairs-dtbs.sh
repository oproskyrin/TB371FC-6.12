#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

base=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r57-boot-log-region-reserved-dtb/sm8250-lenovo-tb371fc-archsafe-microsd.dtb
base_sha=aacb6fbcaf9422912ca766facd9242c39c64def09c39b0c729662da0e785ffb7
out=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r93-r94-upper-large-pairs-dtbs

printf '%s  %s\n' "$base_sha" "$base" | sha256sum -c -
test ! -e "$out" || { echo "Refusing to overwrite $out" >&2; exit 1; }
mkdir -p "$out"

make_dtb() {
  name=$1
  shift
  cp --reflink=auto "$base" "$out/$name.dtb"
  fdtput -t x "$out/$name.dtb" /memory@80000000 reg "$@"
  dtc -q -I dtb -O dts -o "$out/$name.dts" "$out/$name.dtb"
}

# r92 failed with all four large upper ranges 15-18. Split them into pairs.
# Both candidates retain the hardware-proven r87 payload bank.
make_dtb r93-known-plus-upper-large-15-16 \
  0x0 0x90500000 0x0 0x0bb00000 \
  0x2 0x00000000 0x0 0x20000000 \
  0x2 0x20000000 0x0 0x20000000

make_dtb r94-known-plus-upper-large-17-18 \
  0x0 0x90500000 0x0 0x0bb00000 \
  0x2 0x40000000 0x0 0x20000000 \
  0x2 0x60000000 0x0 0x20000000

test "$(fdtget -t x "$out/r93-known-plus-upper-large-15-16.dtb" /memory@80000000 reg | wc -w)" = 12
test "$(fdtget -t x "$out/r94-known-plus-upper-large-17-18.dtb" /memory@80000000 reg | wc -w)" = 12

cat >"$out/BUILD-INFO.txt" <<'EOF'
TB371FC Linux 6.12 r93/r94 large upper RAM-map pair bisection

r92 (known-good payload bank + four contiguous 512 MiB ranges 15-18) did not
reach the r64 post-paging_init checkpoint in more than 60 seconds.

r93 = known bank + large ranges 15-16 (0x200000000-0x23fffffff)
r94 = known bank + large ranges 17-18 (0x240000000-0x27fffffff)

Only /memory@80000000/reg differs from the exact r57 base DTB.
EOF
( cd "$out"; sha256sum *.dtb *.dts BUILD-INFO.txt >SHA256SUMS; sha256sum -c SHA256SUMS )
sha256sum "$out"/*.dtb
