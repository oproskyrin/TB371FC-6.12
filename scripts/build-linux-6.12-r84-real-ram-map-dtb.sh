#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

base=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r57-boot-log-region-reserved-dtb
base_dtb=$base/sm8250-lenovo-tb371fc-archsafe-microsd.dtb
base_sha=aacb6fbcaf9422912ca766facd9242c39c64def09c39b0c729662da0e785ffb7
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r84-real-ram-map-dtb
dtb=$package/sm8250-lenovo-tb371fc-archsafe-microsd-real-ram.dtb

test -s "$base_dtb"
printf '%s  %s\n' "$base_sha" "$base_dtb" | sha256sum -c -
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }
for tool in fdtget fdtput dtc; do command -v "$tool" >/dev/null; done

test "$(fdtget -t x "$base_dtb" /memory@80000000 reg)" = "0 80000000 0 0"
test "$(fdtget -t x "$base_dtb" / '#address-cells')" = "2"
test "$(fdtget -t x "$base_dtb" / '#size-cells')" = "2"

mkdir -p "$package"
cp --reflink=auto "$base_dtb" "$dtb"

# The community DT inherits a zero-size memory placeholder from sm8250.dtsi.
# ABL normally replaces it on a cold Android boot, but our kexec path passes the
# static DTB directly to Linux 6.12. Encode the 19 usable System RAM ranges
# reported by the running V56.6 kernel/kexec-tools after firmware holes were
# subtracted. Each tuple is <address-hi address-lo size-hi size-lo>.
fdtput -t x "$dtb" /memory@80000000 reg \
  0x0 0x80600000 0x0 0x00100000 \
  0x0 0x80894000 0x0 0x0006c000 \
  0x0 0x85e00000 0x0 0x00400000 \
  0x0 0x8681c000 0x0 0x000e4000 \
  0x0 0x90500000 0x0 0x0bb00000 \
  0x0 0x9e400000 0x0 0x03c00000 \
  0x0 0xa2400000 0x0 0x0c219000 \
  0x0 0xae707000 0x0 0x00113000 \
  0x0 0xaffff000 0x0 0x00001000 \
  0x0 0xb0080000 0x0 0x0ba7f000 \
  0x0 0xc0000000 0x0 0x2a000000 \
  0x0 0xffc20000 0x0 0xf8fe0000 \
  0x1 0xf9a00000 0x0 0x001ee000 \
  0x1 0xffa00000 0x0 0x0002d000 \
  0x1 0xffbed000 0x0 0x00002000 \
  0x2 0x00000000 0x0 0x20000000 \
  0x2 0x20000000 0x0 0x20000000 \
  0x2 0x40000000 0x0 0x20000000 \
  0x2 0x60000000 0x0 0x20000000

fdtget -t x "$dtb" /memory@80000000 reg >"$package/memory-reg.cells"
python3 - "$package/memory-reg.cells" <<'PYEOF'
import sys

cells = [int(v, 16) for v in open(sys.argv[1], encoding="ascii").read().split()]
assert len(cells) == 19 * 4, len(cells)
ranges = []
for i in range(0, len(cells), 4):
    start = (cells[i] << 32) | cells[i + 1]
    size = (cells[i + 2] << 32) | cells[i + 3]
    assert start % 4096 == 0 and size > 0 and size % 4096 == 0
    if ranges:
        assert ranges[-1][0] + ranges[-1][1] <= start
    ranges.append((start, size))
assert ranges[0] == (0x80600000, 0x100000)
assert ranges[-1] == (0x260000000, 0x20000000)
assert sum(size for _, size in ranges) == 0x1CACF9000
PYEOF

dtc -q -I dtb -O dts -o "$package/board.real-ram.decompiled.dts" "$dtb"
grep -Fq 'memory@80000000 {' "$package/board.real-ram.decompiled.dts"
grep -Fq 'reg = <0x00 0x80600000 0x00 0x100000' "$package/board.real-ram.decompiled.dts"

cat >"$package/BUILD-INFO.txt" <<EOF
TB371FC Linux 6.12 r84 -- real RAM map DTB

Base DTB SHA-256: $base_sha
Base memory reg: <0x0 0x80000000 0x0 0x0> (zero bytes; invalid for kexec)
New memory reg: 19 exact usable System RAM ranges reported by V56.6
Usable total: 0x1cacf9000 bytes (7,517,156 KiB)

Only /memory@80000000/reg is intentionally changed. The r57 reserved-memory
nodes and every other board property remain inherited from the exact r57 DTB.
This is a diagnostic DTB, not yet a release artifact.
EOF

( cd "$package"; sha256sum "$(basename "$dtb")" memory-reg.cells board.real-ram.decompiled.dts BUILD-INFO.txt >SHA256SUMS; sha256sum -c SHA256SUMS )
fdtget -t x "$dtb" /memory@80000000 reg
sha256sum "$dtb"

