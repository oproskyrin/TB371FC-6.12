#!/usr/bin/env bash
# R180: read-only display register dump module for the first-stage 4.19 console (v56.6, signed with
# that build's key) and for Linux 6.12 (R146 single-CTL native-display tree and the R177 tree).
set -euo pipefail
p="$(cd "$(dirname "$0")/.." && pwd)"
pkg=/mnt/d/TB371FC-builds/r180-regdump; mkdir -p "$pkg"
# 4.19 console
o=/root/tb371fc-desktop-v56-6-watchdog-kexec-out; s=/root/tb371fc-desktop-v56-6-watchdog-kexec-src
m=/root/tb371fc/r180-regdump-419; rm -rf "$m"; mkdir -p "$m"; cp "$p"/scripts/r180-regdump/tb371fc-regdump.c "$p"/scripts/r180-regdump/Makefile "$m/"
export PATH=/root/snapdragon-clang-10.0.7/bin:$PATH
cc=$(sed -n 's/^cmd_kernel\/async.o := \([^ ]*\) .*/\1/p' "$o/kernel/.async.o.cmd")
xc=$(grep -o -- "--target=[^ ]*\|CROSS_COMPILE=[^ ]*" "$o/kernel/.async.o.cmd" | head -1)
echo "cc=$cc $xc"
make -C "$s" O="$o" ARCH=arm64 CC=clang CLANG_TRIPLE=aarch64-linux-gnu- CROSS_COMPILE=aarch64-linux-gnu- M="$m" modules > "$pkg/build-419.log" 2>&1 || { tail -20 "$pkg/build-419.log"; exit 1; }
"$o/scripts/sign-file" sha512 "$o/certs/signing_key.pem" "$o/certs/signing_key.x509" "$m/tb371fc-regdump.ko"
modinfo -F vermagic "$m/tb371fc-regdump.ko"; cp "$m/tb371fc-regdump.ko" "$pkg/tb371fc-regdump-419.ko"
# 6.12 (same module ABI for the R146 tree and the R177 tree: build against each)
for t in r146-single-ctl r159-audio; do
  case $t in r146-single-ctl) src=/root/tb371fc/linux-6.12-r146-single-ctl; out=/root/tb371fc/build-6.12-r146-single-ctl;; *) src=/root/tb371fc/linux-6.12-donor-r118; out=/root/tb371fc/build-6.12-r159-audio;; esac
  m=/root/tb371fc/r180-regdump-$t; rm -rf "$m"; mkdir -p "$m"; cp "$p"/scripts/r180-regdump/tb371fc-regdump.c "$m/"; echo 'obj-m := tb371fc-regdump.o' > "$m/Kbuild"
  make -C "$src" O="$out" ARCH=arm64 LLVM=-18 M="$m" modules > "$pkg/build-$t.log" 2>&1 || { tail -20 "$pkg/build-$t.log"; exit 1; }
  modinfo -F vermagic "$m/tb371fc-regdump.ko"; cp "$m/tb371fc-regdump.ko" "$pkg/tb371fc-regdump-$t.ko"
done
sha256sum "$pkg"/*.ko
