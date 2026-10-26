#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

base=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r57-boot-log-region-reserved-dtb/sm8250-lenovo-tb371fc-archsafe-microsd.dtb
base_sha=aacb6fbcaf9422912ca766facd9242c39c64def09c39b0c729662da0e785ffb7
out=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r91-r92-upper-bisect-dtbs

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

# Split the r88 failing upper group. Both retain the r87 PASS payload bank.
make_dtb r91-known-plus-upper-small \
  0x0 0x90500000 0x0 0x0bb00000 \
  0x1 0xf9a00000 0x0 0x001ee000 \
  0x1 0xffa00000 0x0 0x0002d000 \
  0x1 0xffbed000 0x0 0x00002000

make_dtb r92-known-plus-upper-large \
  0x0 0x90500000 0x0 0x0bb00000 \
  0x2 0x00000000 0x0 0x20000000 \
  0x2 0x20000000 0x0 0x20000000 \
  0x2 0x40000000 0x0 0x20000000 \
  0x2 0x60000000 0x0 0x20000000

test "$(fdtget -t x "$out/r91-known-plus-upper-small.dtb" /memory@80000000 reg | wc -w)" = 16
test "$(fdtget -t x "$out/r92-known-plus-upper-large.dtb" /memory@80000000 reg | wc -w)" = 20

cat >"$out/BUILD-INFO.txt" <<'EOF'
TB371FC Linux 6.12 r91/r92 upper RAM-map bisection

r88 (known-good payload bank + all upper ranges 12-18) did not reach the r64
post-paging_init checkpoint. These two DTBs split that failing group:

r91 = known bank + three tiny upper ranges 12-14
r92 = known bank + four contiguous 512 MiB ranges 15-18

Only /memory@80000000/reg differs from the exact r57 base DTB.
EOF
( cd "$out"; sha256sum *.dtb *.dts BUILD-INFO.txt >SHA256SUMS; sha256sum -c SHA256SUMS )
sha256sum "$out"/*.dtb

