#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

base=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r57-boot-log-region-reserved-dtb/sm8250-lenovo-tb371fc-archsafe-microsd.dtb
base_sha=aacb6fbcaf9422912ca766facd9242c39c64def09c39b0c729662da0e785ffb7
out=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r88-r90-ram-map-bisect-dtbs

test -s "$base"
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

# All candidates include known-good payload bank index 4:
#   0x90500000 + 0x0bb00000
# r88 adds only upper ranges 12-18.
make_dtb r88-known-plus-upper \
  0x0 0x90500000 0x0 0x0bb00000 \
  0x1 0xf9a00000 0x0 0x001ee000 \
  0x1 0xffa00000 0x0 0x0002d000 \
  0x1 0xffbed000 0x0 0x00002000 \
  0x2 0x00000000 0x0 0x20000000 \
  0x2 0x20000000 0x0 0x20000000 \
  0x2 0x40000000 0x0 0x20000000 \
  0x2 0x60000000 0x0 0x20000000

# r89 adds only middle ranges 5-11.
make_dtb r89-known-plus-middle \
  0x0 0x90500000 0x0 0x0bb00000 \
  0x0 0x9e400000 0x0 0x03c00000 \
  0x0 0xa2400000 0x0 0x0c219000 \
  0x0 0xae707000 0x0 0x00113000 \
  0x0 0xaffff000 0x0 0x00001000 \
  0x0 0xb0080000 0x0 0x0ba7f000 \
  0x0 0xc0000000 0x0 0x2a000000 \
  0x0 0xffc20000 0x0 0xf8fe0000

# r90 adds only lower ranges 0-3.
make_dtb r90-lower-plus-known \
  0x0 0x80600000 0x0 0x00100000 \
  0x0 0x80894000 0x0 0x0006c000 \
  0x0 0x85e00000 0x0 0x00400000 \
  0x0 0x8681c000 0x0 0x000e4000 \
  0x0 0x90500000 0x0 0x0bb00000

# r91/r92 split the r88 failing upper group.
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

test "$(fdtget -t x "$out/r88-known-plus-upper.dtb" /memory@80000000 reg | wc -w)" = 32
test "$(fdtget -t x "$out/r89-known-plus-middle.dtb" /memory@80000000 reg | wc -w)" = 32
test "$(fdtget -t x "$out/r90-lower-plus-known.dtb" /memory@80000000 reg | wc -w)" = 20
test "$(fdtget -t x "$out/r91-known-plus-upper-small.dtb" /memory@80000000 reg | wc -w)" = 16
test "$(fdtget -t x "$out/r92-known-plus-upper-large.dtb" /memory@80000000 reg | wc -w)" = 20

cat >"$out/BUILD-INFO.txt" <<'EOF'
TB371FC Linux 6.12 RAM-map bisection DTBs

Exact r57 DTB base; only /memory@80000000/reg changes.
All candidates include the r87 hardware-PASS payload bank (index 4).

r88 = known bank + upper ranges 12-18
r89 = known bank + middle ranges 5-11
r90 = lower ranges 0-3 + known bank
r91 = known bank + upper tiny ranges 12-14
r92 = known bank + four contiguous 512 MiB ranges 15-18

These DTBs are intended for RAM-only replacement in the already-flashed r87
recovery. They use the exact r64 post-paging_init checkpoint Image. They are
diagnostics, not full-boot/release DTBs.
EOF
( cd "$out"; sha256sum *.dtb *.dts BUILD-INFO.txt >SHA256SUMS; sha256sum -c SHA256SUMS )
sha256sum "$out"/*.dtb
