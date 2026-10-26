#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

base=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r57-boot-log-region-reserved-dtb
base_dtb=$base/sm8250-lenovo-tb371fc-archsafe-microsd.dtb
base_sha=aacb6fbcaf9422912ca766facd9242c39c64def09c39b0c729662da0e785ffb7
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r87-minimal-kexec-bank-dtb
dtb=$package/sm8250-lenovo-tb371fc-archsafe-microsd-minimal-bank.dtb

test -s "$base_dtb"
printf '%s  %s\n' "$base_sha" "$base_dtb" | sha256sum -c -
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }
test "$(fdtget -t x "$base_dtb" /memory@80000000 reg)" = "0 80000000 0 0"

mkdir -p "$package"
cp --reflink=auto "$base_dtb" "$dtb"

# Minimal controlled map: this exact V56.6 System RAM range contains all known
# kexec segments (kernel 0x90600000..0x93aaffff, initrd around 0x93ab0000,
# DTB/purgatory around 0x94ad0000) and leaves ample free space for early
# allocations. It ends immediately before cont_splash_mem at 0x9c000000.
fdtput -t x "$dtb" /memory@80000000 reg 0x0 0x90500000 0x0 0x0bb00000
test "$(fdtget -t x "$dtb" /memory@80000000 reg)" = "0 90500000 0 bb00000"
dtc -q -I dtb -O dts -o "$package/board.minimal-bank.decompiled.dts" "$dtb"
grep -Fq 'reg = <0x00 0x90500000 0x00 0xbb00000>;' "$package/board.minimal-bank.decompiled.dts"

cat >"$package/BUILD-INFO.txt" <<EOF
TB371FC Linux 6.12 r87 -- minimal kexec-bank DTB

Base DTB SHA-256: $base_sha
Only /memory@80000000/reg changes:
  old = <0x0 0x80000000 0x0 0x0>
  new = <0x0 0x90500000 0x0 0x0bb00000>

This 187 MiB diagnostic bank contains all observed kexec segments and excludes
every other physical range. It tests whether r86 fails due to the total 19-bank
linear-map workload/a particular later bank, or while mapping the payload bank
itself. This is not a full-boot/release DTB.
EOF

( cd "$package"; sha256sum "$(basename "$dtb")" board.minimal-bank.decompiled.dts BUILD-INFO.txt >SHA256SUMS; sha256sum -c SHA256SUMS )
sha256sum "$dtb"

